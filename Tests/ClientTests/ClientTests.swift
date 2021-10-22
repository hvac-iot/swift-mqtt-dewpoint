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
  
//  func test_fetch_humidity() throws {
//    let lock = Lock()
//    let mqttClient = createMQTTClient(identifier: "fetchHumidity")
//
////    let exp = XCTestExpectation(description: "fetchHumidity")
//
//    let client = try createClient(mqttClient: mqttClient)
//    var humidityRecieved: [RelativeHumidity] = []
//
//    _ = try mqttClient.publish(
//      to: topics.sensors.humidity,
//      payload: ByteBufferAllocator().buffer(string: "\(50.0)"),
//      qos: .atLeastOnce
//    ).wait()
//
//    Thread.sleep(forTimeInterval: 2)
//
////      .flatMapThrowing { _ in
//        let humidity = try client.fetchHumidity(.init(topic: self.topics.sensors.humidity)).wait()
//        XCTAssertEqual(humidity, 50)
//        lock.withLock {
//          humidityRecieved.append(humidity)
//        }
////        exp.fulfill()
////      }.wait()
//
//    Thread.sleep(forTimeInterval: 2)
//    lock.withLock {
//      XCTAssertEqual(humidityRecieved.count, 1)
//    }
//
//    try mqttClient.disconnect().wait()
//    try mqttClient.syncShutdownGracefully()
//
//  }
  
  // MARK: - Helpers
  func createMQTTClient(identifier: String) -> MQTTNIO.MQTTClient {
    MQTTNIO.MQTTClient(
          host: Self.hostname,
          port: 1883,
          identifier: identifier,
          eventLoopGroupProvider: .createNew,
          logger: self.logger,
          configuration: .init(version: .v5_0)
      )
  }
  
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
}
