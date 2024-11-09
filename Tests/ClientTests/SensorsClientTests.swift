@testable import ClientLive
import EnvVars
import Logging
import Models
import MQTTNIO
import NIO
import Psychrometrics
import XCTest

final class SensorsClientTests: XCTestCase {

  static let hostname = ProcessInfo.processInfo.environment["MOSQUITTO_SERVER"] ?? "localhost"

  static let logger: Logger = {
    var logger = Logger(label: "AsyncClientTests")
    logger.logLevel = .debug
    return logger
  }()

  func createClient(identifier: String) -> SensorsClient {
    let envVars = EnvVars(
      appEnv: .testing,
      host: Self.hostname,
      port: "1883",
      identifier: identifier,
      userName: nil,
      password: nil
    )
    return .init(envVars: envVars, logger: Self.logger)
  }

  func testConnectAndShutdown() async throws {
    let client = createClient(identifier: "testConnectAndShutdown")
    await client.connect()
    await client.shutdown()
  }

  func testSensorService() async throws {
    let client = createClient(identifier: "testSensorService")
    let mqtt = await client.client
    let sensor = TemperatureAndHumiditySensor(location: .mixedAir, units: .metric)
    let publishInfo = PublishInfoContainer(topicFilters: [
      sensor.topics.dewPoint,
      sensor.topics.enthalpy
    ])
    let service = SensorsService(client: mqtt, sensors: [sensor])

    // fix to connect the mqtt client.
    await client.connect()
    let task = Task { try await service.run() }

    _ = try await mqtt.subscribe(to: [
      .init(topicFilter: sensor.topics.dewPoint, qos: .exactlyOnce),
      .init(topicFilter: sensor.topics.enthalpy, qos: .exactlyOnce)
    ])

    let listener = mqtt.createPublishListener()
    Task {
      for await result in listener {
        switch result {
        case let .failure(error):
          XCTFail("\(error)")
        case let .success(value):
          await publishInfo.addPublishInfo(value)
        }
      }
    }

    try await mqtt.publish(
      to: sensor.topics.temperature,
      payload: ByteBufferAllocator().buffer(string: "75.123"),
      qos: .exactlyOnce,
      retain: true
    )

    try await Task.sleep(for: .seconds(1))

    // XCTAssert(client.sensors.first!.needsProcessed)
//     let firstSensor = await client.sensors.first!
//     XCTAssertEqual(firstSensor.temperature, .init(75.123, units: .celsius))

    try await mqtt.publish(
      to: sensor.topics.humidity,
      payload: ByteBufferAllocator().buffer(string: "50"),
      qos: .exactlyOnce,
      retain: true
    )

    try await Task.sleep(for: .seconds(1))

    XCTAssertEqual(publishInfo.info.count, 2)

    // fix to shutdown the mqtt client.
    task.cancel()
    await client.shutdown()
  }

  func testSensorCapturesPublishedState() async throws {
    let client = createClient(identifier: "testSensorCapturesPublishedState")
    let mqtt = await client.client
    let sensor = TemperatureAndHumiditySensor(location: .mixedAir, units: .metric)
    let publishInfo = PublishInfoContainer(topicFilters: [
      sensor.topics.dewPoint,
      sensor.topics.enthalpy
    ])

    try await client.addSensor(sensor)
    await client.connect()
    try await client.start()

    _ = try await mqtt.subscribe(to: [
      .init(topicFilter: sensor.topics.dewPoint, qos: .exactlyOnce),
      .init(topicFilter: sensor.topics.enthalpy, qos: .exactlyOnce)
    ])

    let listener = mqtt.createPublishListener()
    Task {
      for await result in listener {
        switch result {
        case let .failure(error):
          XCTFail("\(error)")
        case let .success(value):
          await publishInfo.addPublishInfo(value)
        }
      }
    }

    try await mqtt.publish(
      to: sensor.topics.temperature,
      payload: ByteBufferAllocator().buffer(string: "75.123"),
      qos: .exactlyOnce,
      retain: true
    )

    try await Task.sleep(for: .seconds(1))

    // XCTAssert(client.sensors.first!.needsProcessed)
    let firstSensor = await client.sensors.first!
    XCTAssertEqual(firstSensor.temperature, .init(75.123, units: .celsius))

    try await mqtt.publish(
      to: sensor.topics.humidity,
      payload: ByteBufferAllocator().buffer(string: "50"),
      qos: .exactlyOnce,
      retain: true
    )

    try await Task.sleep(for: .seconds(1))

    XCTAssertEqual(publishInfo.info.count, 2)

    await client.shutdown()
  }
}

// MARK: Helpers for tests.

class PublishInfoContainer {
  private(set) var info: [MQTTPublishInfo]
  private var topicFilters: [String]?

  init(topicFilters: [String]? = nil) {
    self.info = []
    self.topicFilters = topicFilters
  }

  func addPublishInfo(_ info: MQTTPublishInfo) async {
    guard let topicFilters else {
      self.info.append(info)
      return
    }
    if topicFilters.contains(info.topicName) {
      self.info.append(info)
    }
  }
}
