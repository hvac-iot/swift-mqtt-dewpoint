import Dependencies
import Logging
import Models
import MQTTConnectionManager
import ServiceLifecycle

public actor MQTTConnectionService: Service {
  @Dependency(\.mqttConnectionManager) var manager

  private nonisolated let logger: Logger?

  public init(
    logger: Logger? = nil
  ) {
    self.logger = logger
  }

  /// The entry-point of the service which starts the connection
  /// to the MQTT broker and handles graceful shutdown of the
  /// connection.
  public func run() async throws {
    try await withGracefulShutdownHandler {
      try await manager.connect()
      for await event in try manager.stream().cancelOnGracefulShutdown() {
        // We don't really need to do anything with the events, so just logging
        // for now.  But we need to iterate on an async stream for the service to
        // continue to run and handle graceful shutdowns.
        logger?.trace("Received connection event: \(event)")
      }
      // when we reach here we are shutting down, so we shutdown
      // the manager.
      manager.shutdown()
    } onGracefulShutdown: {
      self.logger?.trace("Received graceful shutdown.")
    }
  }
}
