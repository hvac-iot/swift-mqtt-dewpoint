import Client
@testable import ClientLive
import CoreUnitTypes
import Foundation
import Logging
import Models
import MQTTNIO
import NIO
import NIOConcurrencyHelpers
import XCTest

// Can't seem to get tests to work, although we get values when ran from command line.
final class ClientLiveTests: XCTestCase {
  static let hostname = ProcessInfo.processInfo.environment["MOSQUITTO_SERVER"] ?? "localhost"
  let topics = Topics()
  
  func test_mqtt_subscription() throws {
    let mqttClient = createMQTTClient(identifier: "test_subscription")
    _ = try mqttClient.connect().wait()
    let sub = try mqttClient.v5.subscribe(
      to: [mqttClient.mqttSubscription(topic: "test/subscription")]
    ).wait()
    XCTAssertEqual(sub.reasons[0], .grantedQoS1)
    try mqttClient.disconnect().wait()
    try mqttClient.syncShutdownGracefully()
  }
  
  func test_mqtt_listener() throws {
    let lock = Lock()
    var publishRecieved: [MQTTPublishInfo] = []
    let payloadString = "test"
    let payload = ByteBufferAllocator().buffer(string: payloadString)
    
    let client = self.createMQTTClient(identifier: "testMQTTListener_publisher")
    _ = try client.connect().wait()
    client.addPublishListener(named: "test") { result in
      switch result {
      case .success(let publish):
        var buffer = publish.payload
        let string = buffer.readString(length: buffer.readableBytes)
        XCTAssertEqual(string, payloadString)
        lock.withLock {
          publishRecieved.append(publish)
        }
      case .failure(let error):
        XCTFail("\(error)")
      }
    }
    
    try client.publish(to: "testMQTTSubscribe", payload: payload, qos: .atLeastOnce, retain: true).wait()
    let sub = try client.v5.subscribe(to: [.init(topicFilter: "testMQTTSubscribe", qos: .atLeastOnce)]).wait()
    XCTAssertEqual(sub.reasons[0], .grantedQoS1)
    
    Thread.sleep(forTimeInterval: 2)
    lock.withLock {
      XCTAssertEqual(publishRecieved.count, 1)
    }
    
    try client.disconnect().wait()
    try client.syncShutdownGracefully()
    
  }
  
//  func test_fetch_humidity() throws {
//    let lock = Lock()
//    let publishClient = createMQTTClient(identifier: "publishHumidity")
//    let mqttClient = createMQTTClient(identifier: "fetchHumidity")
//    _ = try publishClient.connect().wait()
//    let client = try createClient(mqttClient: mqttClient)
//    var humidityRecieved: [RelativeHumidity] = []
//
//    _ = try publishClient.publish(
//      to: topics.sensors.humidity,
//      payload: ByteBufferAllocator().buffer(string: "\(50.0)"),
//      qos: .atLeastOnce
//    ).wait()
//
//    Thread.sleep(forTimeInterval: 2)
//    try publishClient.disconnect().wait()
//    let humidity = try client.fetchHumidity(.init(topic: self.topics.sensors.humidity)).wait()
//    XCTAssertEqual(humidity, 50)
//    Thread.sleep(forTimeInterval: 2)
//    lock.withLock {
//      humidityRecieved.append(humidity)
//    }
//    try mqttClient.disconnect().wait()
//    try mqttClient.syncShutdownGracefully()
//  }
  
  // MARK: - Helpers
  func createMQTTClient(identifier: String) -> MQTTNIO.MQTTClient {
    MQTTNIO.MQTTClient(
          host: Self.hostname,
          port: 1883,
          identifier: identifier,
          eventLoopGroupProvider: .shared(eventLoopGroup),
          logger: self.logger,
          configuration: .init(version: .v5_0)
      )
  }
  
//  func createWebSocketClient(identifier: String) -> MQTTNIO.MQTTClient {
//    MQTTNIO.MQTTClient(
//          host: Self.hostname,
//          port: 8080,
//          identifier: identifier,
//          eventLoopGroupProvider: .createNew,
//          logger: self.logger,
//          configuration: .init(useWebSockets: true, webSocketURLPath: "/mqtt")
//      )
//  }
  
  // Uses default topic names.
  func createClient(mqttClient: MQTTNIO.MQTTClient, autoConnect: Bool = true) throws -> Client.MQTTClient {
    if autoConnect {
      _ = try mqttClient.connect().wait()
    }
    return .live(client: mqttClient, topics: .init())
  }
  
  let logger: Logger = {
      var logger = Logger(label: "MQTTTests")
      logger.logLevel = .trace
      return logger
  }()
  
  let eventLoopGroup = MultiThreadedEventLoopGroup.init(numberOfThreads: 1)
}
