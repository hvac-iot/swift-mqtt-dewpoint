import EnvVars
import Logging
@testable import MQTTConnectionService
import MQTTNIO
import NIO
import ServiceLifecycle
import ServiceLifecycleTestKit
import XCTest

final class MQTTConnectionServiceTests: XCTestCase {

  static let hostname = ProcessInfo.processInfo.environment["MOSQUITTO_SERVER"] ?? "localhost"

  static let logger: Logger = {
    var logger = Logger(label: "AsyncClientTests")
    logger.logLevel = .trace
    return logger
  }()

  func testGracefulShutdownWorks() async throws {
    try await testGracefulShutdown { trigger in
      let client = createClient(identifier: "testGracefulShutdown")
      let service = MQTTConnectionService(client: client)
      try await service.run()
      try await Task.sleep(for: .seconds(1))
      XCTAssert(client.isActive())
      trigger.triggerGracefulShutdown()
    }
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
