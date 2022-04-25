import Foundation
import EnvVars
import Logging
import Models
import MQTTNIO
import NIO

public class MQTTClientConnection {
  
  static func parsePort(port: String?) -> Int {
    guard let port = port, let int = Int(port) else {
      return 1883
    }
    return int
  }
  
  let client: MQTTClient
  var shuttingDown: Bool
  var logger: Logger? { client.logger }
  
  public init(
    envVars: EnvVars,
    eventLoopGroupProvider: NIOEventLoopGroupProvider = .createNew
  ) {
    let configuration = MQTTClient.Configuration.init(
      version: .v5_0,
      userName: envVars.userName,
      password: envVars.password
    )
    var logger = Logger(label: "DewPointController")
    #if DEBUG
    logger.logLevel = .trace
    #else
    logger.logLevel = .critical
    #endif
    self.client = .init(
      host: envVars.host,
      port: Self.parsePort(port: envVars.port),
      identifier: envVars.identifier,
      eventLoopGroupProvider: eventLoopGroupProvider,
      logger: logger,
      configuration: configuration
    )
    self.shuttingDown = false
  }
  
  deinit {
    Task { await shutdown() }
  }
  
  public func connect() async {
    do {
      _ = try await client.connect()
      client.addCloseListener(named: "DewPointController") { _ in
        guard !self.shuttingDown else { return }
        self.logger?.info("Connection closed, reconnecting...")
        Task { await self.connect() }
      }
      logger?.info("Connected to MQTT Broker")
    } catch {
      logger?.debug("Failed to connect.\n\(error)")
    }
  }
  
  public func shutdown() async {
    shuttingDown = true
    try? await client.disconnect()
    try? await client.shutdown()
  }
}
