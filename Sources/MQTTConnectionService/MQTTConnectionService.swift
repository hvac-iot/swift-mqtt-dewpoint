import Dependencies
import DependenciesMacros
import Foundation
import Logging
import Models
import ServiceLifecycle

/// Represents the interface needed for the ``MQTTConnectionService``.
///
/// See ``MQTTConnectionManagerLive`` module for live implementation.
@DependencyClient
public struct MQTTConnectionManager: Sendable {

  public var connect: @Sendable () async throws -> AsyncStream<Event>
  public var shutdown: () -> Void

  public enum Event: Sendable {
    case connected
    case disconnected
    case shuttingDown
  }
}

extension MQTTConnectionManager: TestDependencyKey {
  public static var testValue: MQTTConnectionManager {
    Self()
  }
}

public extension DependencyValues {

  /// A dependency that is responsible for managing the connection to
  /// an MQTT broker.
  var mqttConnectionManager: MQTTConnectionManager {
    get { self[MQTTConnectionManager.self] }
    set { self[MQTTConnectionManager.self] = newValue }
  }
}

// MARK: - MQTTConnectionService

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
      let stream = try await manager.connect()
      for await event in stream.cancelOnGracefulShutdown() {
        // We don't really need to do anything with the events, so just logging
        // for now.  But we need to iterate on an async stream for the service to
        // continue to run and handle graceful shutdowns.
        logger?.trace("Received connection event: \(event)")
      }
      manager.shutdown()
    } onGracefulShutdown: {
      self.logger?.trace("Received graceful shutdown.")
    }
  }
}
