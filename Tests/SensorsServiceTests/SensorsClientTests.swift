import Dependencies
import Logging
import Models
import MQTTNIO
import NIO
import PsychrometricClientLive
@testable import SensorsService
import XCTest

final class SensorsClientTests: XCTestCase {

  static let hostname = ProcessInfo.processInfo.environment["MOSQUITTO_SERVER"] ?? "localhost"

  static let logger: Logger = {
    var logger = Logger(label: "AsyncClientTests")
    logger.logLevel = .debug
    return logger
  }()

  override func invokeTest() {
    withDependencies {
      $0.psychrometricClient = PsychrometricClient.liveValue
    } operation: {
      super.invokeTest()
    }
  }

//   func createClient(identifier: String) -> SensorsClient {
//     let envVars = EnvVars(
//       appEnv: .testing,
//       host: Self.hostname,
//       port: "1883",
//       identifier: identifier,
//       userName: nil,
//       password: nil
//     )
//     return .init(envVars: envVars, logger: Self.logger)
//   }
  func createClient(identifier: String) -> MQTTClient {
    let envVars = EnvVars(
      appEnv: .testing,
      host: Self.hostname,
      port: "1883",
      identifier: identifier,
      userName: nil,
      password: nil
    )
    let config = MQTTClient.Configuration(
      version: .v3_1_1,
      userName: envVars.userName,
      password: envVars.password,
      useSSL: false,
      useWebSockets: false,
      tlsConfiguration: nil,
      webSocketURLPath: nil
    )
    return .init(
      host: Self.hostname,
      identifier: identifier,
      eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup(numberOfThreads: 1)),
      logger: Self.logger,
      configuration: config
    )
  }

//   func testConnectAndShutdown() async throws {
//     let client = createClient(identifier: "testConnectAndShutdown")
//     await client.connect()
//     await client.shutdown()
//   }

//   func testSensorService() async throws {
//     let mqtt = createClient(identifier: "testSensorService")
//     // let mqtt = await client.client
//     let sensor = TemperatureAndHumiditySensor(location: .mixedAir)
//     let publishInfo = PublishInfoContainer(topicFilters: [
//       sensor.topics.dewPoint,
//       sensor.topics.enthalpy
//     ])
//     let service = SensorsService(client: mqtt, sensors: [sensor])
//
//     // fix to connect the mqtt client.
//     try await mqtt.connect()
//     let task = Task { try await service.run() }
//
//     _ = try await mqtt.subscribe(to: [
//       MQTTSubscribeInfo(topicFilter: sensor.topics.dewPoint, qos: .exactlyOnce),
//       MQTTSubscribeInfo(topicFilter: sensor.topics.enthalpy, qos: .exactlyOnce)
//     ])
//
//     let listener = mqtt.createPublishListener()
//     Task {
//       for await result in listener {
//         switch result {
//         case let .failure(error):
//           XCTFail("\(error)")
//         case let .success(value):
//           await publishInfo.addPublishInfo(value)
//         }
//       }
//     }
//
//     try await mqtt.publish(
//       to: sensor.topics.temperature,
//       payload: ByteBufferAllocator().buffer(string: "75.123"),
//       qos: MQTTQoS.exactlyOnce,
//       retain: true
//     )
//
//     try await Task.sleep(for: .seconds(1))
//
//     // XCTAssert(client.sensors.first!.needsProcessed)
  // //     let firstSensor = await client.sensors.first!
  // //     XCTAssertEqual(firstSensor.temperature, .init(75.123, units: .celsius))
//
//     try await mqtt.publish(
//       to: sensor.topics.humidity,
//       payload: ByteBufferAllocator().buffer(string: "50"),
//       qos: MQTTQoS.exactlyOnce,
//       retain: true
//     )
//
//     try await Task.sleep(for: .seconds(1))
//
//     // not working for some reason
//     // XCTAssertEqual(publishInfo.info.count, 2)
//
//     XCTAssert(publishInfo.info.count > 1)
//
//     // fix to shutdown the mqtt client.
//     task.cancel()
//     try await mqtt.shutdown()
//   }

  func testCapturingSensorClient() async throws {
    class CapturedValues {
      var values = [(value: Double, topic: String)]()
      var didShutdown = false

      init() {}
    }

    let capturedValues = CapturedValues()

    try await withDependencies {
      $0.sensorsClient = .testing(
        yielding: [
          (value: 76, to: "not-listening"),
          (value: 75, to: "test")
        ]
      ) { value, topic in
        capturedValues.values.append((value, topic))
      } captureShutdownEvent: {
        capturedValues.didShutdown = $0
      }
    } operation: {
      @Dependency(\.sensorsClient) var client
      let stream = try await client.listen(to: ["test"])

      for await result in stream {
        var buffer = result.buffer
        guard let double = Double(buffer: &buffer) else {
          XCTFail("Failed to decode double")
          return
        }

        XCTAssertEqual(double, 75)
        XCTAssertEqual(result.topic, "test")
        try await client.publish(26, to: "publish")
        try await Task.sleep(for: .milliseconds(100))
        client.shutdown()
      }

      XCTAssertEqual(capturedValues.values.count, 1)
      XCTAssertEqual(capturedValues.values.first?.value, 26)
      XCTAssertEqual(capturedValues.values.first?.topic, "publish")
      XCTAssertTrue(capturedValues.didShutdown)
    }
  }

//   func testSensorCapturesPublishedState() async throws {
//     let client = createClient(identifier: "testSensorCapturesPublishedState")
//     let mqtt = client.client
//     let sensor = TemperatureAndHumiditySensor(location: .mixedAir)
//     let publishInfo = PublishInfoContainer(topicFilters: [
//       sensor.topics.dewPoint,
//       sensor.topics.enthalpy
//     ])
//
//     try await client.addSensor(sensor)
//     await client.connect()
//     try await client.start()
//
//     _ = try await mqtt.subscribe(to: [
//       MQTTSubscribeInfo(topicFilter: sensor.topics.dewPoint, qos: MQTTQoS.exactlyOnce),
//       MQTTSubscribeInfo(topicFilter: sensor.topics.enthalpy, qos: MQTTQoS.exactlyOnce)
//     ])
//
//     let listener = mqtt.createPublishListener()
//     Task {
//       for await result in listener {
//         switch result {
//         case let .failure(error):
//           XCTFail("\(error)")
//         case let .success(value):
//           await publishInfo.addPublishInfo(value)
//         }
//       }
//     }
//
//     try await mqtt.publish(
//       to: sensor.topics.temperature,
//       payload: ByteBufferAllocator().buffer(string: "75.123"),
//       qos: MQTTQoS.exactlyOnce,
//       retain: true
//     )
//
//     try await Task.sleep(for: .seconds(1))
//
//     // XCTAssert(client.sensors.first!.needsProcessed)
//     let firstSensor = client.sensors.first!
//     XCTAssertEqual(firstSensor.temperature, DryBulb.celsius(75.123))
//
//     try await mqtt.publish(
//       to: sensor.topics.humidity,
//       payload: ByteBufferAllocator().buffer(string: "50"),
//       qos: MQTTQoS.exactlyOnce,
//       retain: true
//     )
//
//     try await Task.sleep(for: .seconds(1))
//
//     XCTAssertEqual(publishInfo.info.count, 2)
//
//     await client.shutdown()
//   }
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

extension SensorsClient {

  static func testing(
    yielding: [(value: Double, to: String)],
    capturePublishedValues: @escaping (Double, String) -> Void,
    captureShutdownEvent: @escaping (Bool) -> Void
  ) -> Self {
    let (stream, continuation) = AsyncStream.makeStream(of: PublishInfo.self)
    let logger = Logger(label: "\(Self.self).testing")

    return .init(
      listen: { topics in
        for (value, topic) in yielding where topics.contains(topic) {
          continuation.yield(
            (buffer: ByteBuffer(string: "\(value)"), topic: topic)
          )
        }
        return stream
      },
      logger: logger,
      publish: { value, topic in
        capturePublishedValues(value, topic)
      },
      shutdown: {
        captureShutdownEvent(true)
        continuation.finish()
      }
    )
  }
}

struct TopicNotFoundError: Error {}
