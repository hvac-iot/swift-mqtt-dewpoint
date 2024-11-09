import EnvVars
import Logging
import MQTTConnectionService
import MQTTNIO
import NIO
import ServiceLifecycleTestKit
import XCTest

final class MQTTConnectionServiceTests: XCTestCase {

  static let hostname = ProcessInfo.processInfo.environment["MOSQUITTO_SERVER"] ?? "localhost"

  static let logger: Logger = {
    var logger = Logger(label: "AsyncClientTests")
    logger.logLevel = .debug
    return logger
  }()

  func testGracefulShutdownWorks() async throws {
    let client = createClient(identifier: "testGracefulShutdown")

    try await testGracefulShutdown { trigger in
      let service = MQTTConnectionService(client: client)
      try await service.run()
      trigger.triggerGracefulShutdown()
    }

    try await Task.sleep(for: .seconds(1))

    XCTAssertFalse(client.isActive())
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
