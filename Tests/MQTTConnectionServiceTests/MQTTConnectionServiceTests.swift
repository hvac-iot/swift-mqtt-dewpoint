import Logging
import Models
@testable import MQTTConnectionManager
import MQTTConnectionService
import MQTTNIO
import NIO
import ServiceLifecycle
import ServiceLifecycleTestKit
import XCTest

final class MQTTConnectionServiceTests: XCTestCase {

  static let hostname = ProcessInfo.processInfo.environment["MOSQUITTO_SERVER"] ?? "localhost"

  static let logger: Logger = {
    var logger = Logger(label: "MQTTConnectionServiceTests")
    logger.logLevel = .trace
    return logger
  }()

//   func testGracefulShutdownWorks() async throws {
//     let client = createClient(identifier: "testGracefulShutdown")
//     let service = MQTTConnectionService(client: client)
//     await service.connect()
//     try await Task.sleep(for: .seconds(1))
//     XCTAssert(client.isActive())
//     service.shutdown()
//     XCTAssertFalse(client.isActive())
//   }

  func testWhatHappensIfConnectIsCalledMultipleTimes() async throws {
    let client = createClient(identifier: "testWhatHappensIfConnectIsCalledMultipleTimes")
    let manager = MQTTConnectionManager.live(client: client)
    try await manager.connect()
    try await manager.connect()
  }

  // TODO: Move to integration tests.
  func testMQTTConnectionStream() async throws {
    let client = createClient(identifier: "testNonManagedStream")
    let manager = MQTTConnectionManager.live(
      client: client,
      logger: Self.logger,
      alwaysReconnect: false
    )
    let stream = MQTTConnectionStream(client: client, logger: Self.logger)
    var events = [MQTTConnectionManager.Event]()

    _ = try await manager.connect()

    Task {
      while !client.isActive() {
        try await Task.sleep(for: .milliseconds(100))
      }
      try await Task.sleep(for: .milliseconds(200))
      manager.shutdown()
      try await client.disconnect()
      try await Task.sleep(for: .milliseconds(200))
      try await client.shutdown()
      try await Task.sleep(for: .milliseconds(200))
      stream.stop()
    }

    for await event in stream.removeDuplicates() {
      events.append(event)
    }

    XCTAssertEqual(events, [.disconnected, .connected, .disconnected, .shuttingDown])
  }

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

}
