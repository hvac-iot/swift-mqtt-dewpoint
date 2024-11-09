import EnvVars
import Logging
import MQTTNIO
import NIO
import ServiceLifecycle

/// Manages the MQTT broker connection.
public actor MQTTConnectionService: Service {
  private let cleanSession: Bool
  public let client: MQTTClient
  private var shuttingDown = false
  var logger: Logger { client.logger }

  public init(
    cleanSession: Bool = true,
    client: MQTTClient
  ) {
    self.cleanSession = cleanSession
    self.client = client
  }

  /// The entry-point of the service.
  ///
  /// This method connects to the MQTT broker and manages the connection.
  /// It will attempt to gracefully shutdown the connection upon receiving
  /// `sigterm` signals.
  public func run() async throws {
    await withGracefulShutdownHandler {
      await self.connect()
    } onGracefulShutdown: {
      Task { await self.shutdown() }
    }
  }

  private func shutdown() async {
    shuttingDown = true
    try? await client.disconnect()
    try? await client.shutdown()
  }

  private func connect() async {
    do {
      try await client.connect(cleanSession: cleanSession)
      client.addCloseListener(named: "SensorsClient") { [self] _ in
        Task {
          self.logger.debug("Connection closed.")
          self.logger.debug("Reconnecting...")
          await self.connect()
        }
      }
      logger.debug("Connection successful.")
    } catch {
      logger.trace("Connection Failed.\n\(error)")
    }
  }
}
