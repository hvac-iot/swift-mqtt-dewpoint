import AsyncAlgorithms
import Dependencies
import DependenciesMacros
import Foundation
import Logging
import MQTTNIO
import NIO

public extension DependencyValues {

  /// A dependency that is responsible for managing the connection to
  /// an MQTT broker.
  var mqttConnectionManager: MQTTConnectionManager {
    get { self[MQTTConnectionManager.self] }
    set { self[MQTTConnectionManager.self] = newValue }
  }
}

/// Represents the interface needed for the ``MQTTConnectionService``.
///
/// See ``MQTTConnectionManagerLive`` module for live implementation.
@DependencyClient
public struct MQTTConnectionManager: Sendable {

  /// Connect to the MQTT broker.
  public var connect: @Sendable () async throws -> Void

  /// Shutdown the connection to the MQTT broker.
  ///
  /// - Note: You should cancel any tasks that are listening to the connection stream first.
  public var shutdown: @Sendable () -> Void

  /// Create a stream of connection events.
  public var stream: @Sendable () throws -> AsyncStream<Event>

  /// Represents connection events that clients can listen for and
  /// react accordingly.
  public enum Event: Sendable {
    case connected
    case disconnected
    case shuttingDown
  }

  public static func live(
    client: MQTTClient,
    cleanSession: Bool = false,
    logger: Logger? = nil,
    alwaysReconnect: Bool = true
  ) -> Self {
    let manager = ConnectionManager(
      client: client,
      logger: logger,
      alwaysReconnect: alwaysReconnect
    )
    return .init {
      try await manager.connect(cleanSession: cleanSession)
    } shutdown: {
      manager.shutdown()
    } stream: {
      MQTTConnectionStream(client: client, logger: logger)
        .start()
        .removeDuplicates()
        .eraseToStream()
    }
  }
}

extension MQTTConnectionManager: TestDependencyKey {
  public static var testValue: MQTTConnectionManager {
    Self()
  }
}

// MARK: - Helpers

final class MQTTConnectionStream: AsyncSequence, Sendable {

  typealias AsyncIterator = AsyncStream<Element>.AsyncIterator
  typealias Element = MQTTConnectionManager.Event

  private let client: MQTTClient
  private let continuation: AsyncStream<Element>.Continuation
  private let logger: Logger?
  private let name: String
  private let stream: AsyncStream<Element>

  init(client: MQTTClient, logger: Logger?) {
    let (stream, continuation) = AsyncStream<Element>.makeStream()
    self.client = client
    self.continuation = continuation
    self.logger = logger
    self.name = UUID().uuidString
    self.stream = stream
  }

  deinit { stop() }

  func start(
    isolation: isolated (any Actor)? = #isolation
  ) -> AsyncStream<Element> {
    // Check if the client is active and yield the result.
    continuation.yield(client.isActive() ? .connected : .disconnected)

    // Register listener on the client for when the connection
    // closes.
    client.addCloseListener(named: name) { _ in
      self.logger?.trace("Client has disconnected.")
      self.continuation.yield(.disconnected)
    }

    // Register listener on the client for when the client
    // is shutdown.
    client.addShutdownListener(named: name) { _ in
      self.logger?.trace("Client is shutting down.")
      self.continuation.yield(.shuttingDown)
      self.stop()
    }

    return stream
  }

  func stop() {
    client.removeCloseListener(named: name)
    client.removeShutdownListener(named: name)
    continuation.finish()
  }

  public __consuming func makeAsyncIterator() -> AsyncIterator {
    start().makeAsyncIterator()
  }

}

actor ConnectionManager {
  private let client: MQTTClient
  private let logger: Logger?
  private let name: String
  private let shouldReconnect: Bool
  private var hasConnected: Bool = false

  init(
    client: MQTTClient,
    logger: Logger?,
    alwaysReconnect: Bool
  ) {
    self.client = client
    self.logger = logger
    self.name = UUID().uuidString
    self.shouldReconnect = alwaysReconnect
  }

  deinit {
    // We should've already logged that we're shutting down if
    // the manager was shutdown properly, so don't log it twice.
    self.shutdown(withLogging: false)
  }

  private func setHasConnected() {
    hasConnected = true
  }

  func connect(
    isolation: isolated (any Actor)? = #isolation,
    cleanSession: Bool
  ) async throws {
    guard !(await hasConnected) else { return }
    do {
      try await client.connect(cleanSession: cleanSession)
      await setHasConnected()

      client.addCloseListener(named: name) { [weak self] _ in
        guard let `self` else { return }
        self.logger?.debug("Connection closed.")
        if self.shouldReconnect {
          self.logger?.debug("Reconnecting...")
          Task {
            try await self.connect(cleanSession: cleanSession)
          }
        }
      }

      client.addShutdownListener(named: name) { _ in
        self.shutdown()
      }

    } catch {
      logger?.trace("Failed to connect: \(error)")
      throw error
    }
  }

  nonisolated func shutdown(withLogging: Bool = true) {
    if withLogging {
      logger?.trace("Shutting down connection.")
    }
    client.removeCloseListener(named: name)
    client.removeShutdownListener(named: name)
  }
}
