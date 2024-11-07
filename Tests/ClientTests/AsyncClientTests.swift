import XCTest
import EnvVars
import Logging
import Models
@testable import ClientLive
import Psychrometrics

final class AsyncClientTests: XCTestCase {
  
  static let hostname = ProcessInfo.processInfo.environment["MOSQUITTO_SERVER"] ?? "localhost"
  
  static let logger: Logger = {
    var logger = Logger(label: "AsyncClientTests")
    logger.logLevel = .trace
    return logger
  }()
  
  func createClient(identifier: String) -> AsyncClient {
    let envVars = EnvVars.init(
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
}
