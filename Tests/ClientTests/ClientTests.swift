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

final class ClientLiveTests: XCTestCase {
  static let hostname = ProcessInfo.processInfo.environment["MOSQUITTO_SERVER"] ?? "localhost"
  let topics = Topics()
  
//  func test_mqtt_subscription() throws {
//    let mqttClient = createMQTTClient(identifier: "test_subscription")
//    _ = try mqttClient.connect().wait()
//    let sub = try mqttClient.v5.subscribe(
//      to: [mqttClient.mqttSubscription(topic: "test/subscription")]
//    ).wait()
//    XCTAssertEqual(sub.reasons[0], .grantedQoS1)
//    try mqttClient.disconnect().wait()
//    try mqttClient.syncShutdownGracefully()
//  }
  
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
  
  func test_client2_returnTemperature_listener() throws {
    let mqttClient = createMQTTClient(identifier: "return-temperature-tests")
    let state = State()
    let topics = Topics()
    let client = Client.live(client: mqttClient, state: state, topics: topics)
    
    client.addListeners()
    try client.connect().wait()
    try client.subscribe().wait()
    
    _ = try mqttClient.publish(
      to: topics.sensors.returnAirSensor.temperature,
      payload: ByteBufferAllocator().buffer(string: "75.1234"),
      qos: .atLeastOnce
    ).wait()
    
    Thread.sleep(forTimeInterval: 2)
    
    XCTAssertEqual(state.sensors.returnAirSensor.temperature, .celsius(75.1234))
    
    try client.shutdown().wait()
  }
  
  func test_client2_returnSensor_publish() throws {
    let mqttClient = createMQTTClient(identifier: "return-temperature-tests")
    let state = State()
    let topics = Topics()
    let client = Client.live(client: mqttClient, state: state, topics: topics)
    
    client.addListeners()
    try client.connect().wait()
    try client.subscribe().wait()
    
    _ = try mqttClient.publish(
      to: topics.sensors.returnAirSensor.temperature,
      payload: ByteBufferAllocator().buffer(string: "75.1234"),
      qos: .atLeastOnce
    ).wait()
    
    _ = try mqttClient.publish(
      to: topics.sensors.returnAirSensor.humidity,
      payload: ByteBufferAllocator().buffer(string: "\(50.0)"),
      qos: .atLeastOnce
    ).wait()
    
    Thread.sleep(forTimeInterval: 2)
    XCTAssert(state.sensors.returnAirSensor.needsProcessed)
    
    try client.publishSensor(.return(state.sensors.returnAirSensor)).wait()
    XCTAssertFalse(state.sensors.returnAirSensor.needsProcessed)
    
    try client.shutdown().wait()
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
//  func createClient(mqttClient: MQTTNIO.MQTTClient, autoConnect: Bool = true) throws -> Client.MQTTClient {
//    if autoConnect {
//      _ = try mqttClient.connect().wait()
//    }
//    return .live(client: mqttClient, topics: .init())
//  }
  
  let logger: Logger = {
      var logger = Logger(label: "MQTTTests")
      logger.logLevel = .trace
      return logger
  }()
  
  let eventLoopGroup = MultiThreadedEventLoopGroup.init(numberOfThreads: 1)
}
