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
  nonisolated var logger: Logger { client.logger }

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
    await withDiscardingTaskGroup { group in
      await withGracefulShutdownHandler {
        group.addTask { await self.connect() }
      } onGracefulShutdown: {
        // try? self.client.syncShutdownGracefully()
        Task { await self.shutdown() }
      }
    }
  }

  func shutdown() async {
    shuttingDown = true
    try? await client.disconnect()
    try? await client.shutdown()
  }

  func connect() async {
    do {
      try await withThrowingDiscardingTaskGroup { group in
        group.addTask {
          try await self.client.connect(cleanSession: self.cleanSession)
        }
        client.addCloseListener(named: "SensorsClient") { [self] _ in
          Task {
            self.logger.debug("Connection closed.")
            self.logger.debug("Reconnecting...")
            await self.connect()
          }
        }
        self.logger.debug("Connection successful.")
      }
    } catch {
      logger.trace("Failed to connect.")
    }
//     do {
//       try await client.connect(cleanSession: cleanSession)
//       client.addCloseListener(named: "SensorsClient") { [self] _ in
//         Task {
//           self.logger.debug("Connection closed.")
//           self.logger.debug("Reconnecting...")
//           await self.connect()
//         }
//       }
//       logger.debug("Connection successful.")
//     } catch {
//       logger.trace("Connection Failed.\(error)")
//     }
  }
}
