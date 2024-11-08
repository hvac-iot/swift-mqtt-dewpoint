@testable import ClientLive
import EnvVars
import Logging
import Models
import MQTTNIO
import NIO
import Psychrometrics
import XCTest

final class AsyncClientTests: XCTestCase {

  static let hostname = ProcessInfo.processInfo.environment["MOSQUITTO_SERVER"] ?? "localhost"

  static let logger: Logger = {
    var logger = Logger(label: "AsyncClientTests")
    logger.logLevel = .trace
    return logger
  }()

  func createClient(identifier: String) -> AsyncClient {
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

  func testPublishingSensor() async throws {
    let client = createClient(identifier: "testPublishingSensor")
    await client.connect()
    let topic = Topics().sensors.mixedAirSensor.dewPoint
    try await client.addPublishListener(topic: topic, decoding: Temperature.self)
    try await client.publishSensor(.mixed(.init(temperature: 71.123, humidity: 50.5, needsProcessed: true)))
    try await client.publishSensor(.mixed(.init(temperature: 72.123, humidity: 50.5, needsProcessed: true)))
    await client.shutdown()
  }

  func testSensor() async throws {
    let client = createClient(identifier: "testSensor")
    let mqtt = client.client
    try client.addSensor(.init(location: .mixedAir))
    await client.connect()

    Task { try await client.addSensorListeners() }

    try await mqtt.publish(
      to: "sensors/mixed-air/temperture",
      payload: ByteBufferAllocator().buffer(string: "75.123"),
      qos: .atLeastOnce
    )

    try await Task.sleep(for: .seconds(2))

    XCTAssert(client.sensors.first!.needsProcessed)
    XCTAssertEqual(client.sensors.first!.temperature, 75.123)

    await client.shutdown()
  }

//   func testNewSensorSyntax() async throws {
//     let client = createClient(identifier: "testNewSensorSyntax")
//     let mqtt = client.client
//     let receivedPublishInfo = PublishInfoContainer()
//     let payload = ByteBufferAllocator().buffer(string: "75.123")
//     let sensor = TemperatureAndHumiditySensor(location: .return)
//
//     await client.connect()
//
//     try await mqtt.subscribeToTemperature(sensor: sensor)
//
//     let listener = mqtt.createPublishListener()
//
//     Task { [receivedPublishInfo] in
//       for await result in listener {
//         switch result {
//         case let .failure(error):
//           XCTFail("\(error)")
//         case let .success(publish):
//           await receivedPublishInfo.addPublishInfo(publish)
//         }
//       }
//     }
//
//     try await mqtt.publish(to: sensor.topics.temperature, payload: payload, qos: .atLeastOnce)
//
//     try await Task.sleep(for: .seconds(2))
//
//     XCTAssertEqual(receivedPublishInfo.count, 1)
//
//     if let publish = receivedPublishInfo.first {
//       var buffer = publish.payload
//       let string = buffer.readString(length: buffer.readableBytes)
//       XCTAssertEqual(string, "75.123")
//     } else {
//       XCTFail("Did not receive any publish info.")
//     }
//
//     try await mqtt.disconnect()
//     try mqtt.syncShutdownGracefully()
//   }
}

// MARK: Helpers for tests, some of these should be able to be removed once the AsyncClient interface is done.

extension MQTTClient {

  func subscribeToTemperature(sensor: TemperatureAndHumiditySensor) async throws {
    _ = try await subscribe(to: [
      .init(topicFilter: sensor.topics.temperature, qos: .atLeastOnce)
    ])
  }
}

class PublishInfoContainer {
  private var receivedPublishInfo: [MQTTPublishInfo]

  init() {
    self.receivedPublishInfo = []
  }

  func addPublishInfo(_ info: MQTTPublishInfo) async {
    receivedPublishInfo.append(info)
  }

  var count: Int { receivedPublishInfo.count }

  var first: MQTTPublishInfo? { receivedPublishInfo.first }
}
