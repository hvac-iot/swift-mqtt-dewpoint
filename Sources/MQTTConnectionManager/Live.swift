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
      MQTTConnectionStream(client: client)
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
  private var logger: Logger { client.logger }
  private let name: String
  private let stream: AsyncStream<Element>

  init(client: MQTTClient) {
    let (stream, continuation) = AsyncStream<Element>.makeStream()
    self.client = client
    self.continuation = continuation
    self.name = UUID().uuidString
    self.stream = stream
    continuation.yield(client.isActive() ? .connected : .disconnected)
  }

  deinit { stop() }

  func start(
    isolation: isolated (any Actor)? = #isolation
  ) -> AsyncStream<Element> {
    client.addCloseListener(named: name) { _ in
      self.logger.trace("Client has disconnected.")
      self.continuation.yield(.disconnected)
    }
    client.addShutdownListener(named: name) { _ in
      self.logger.trace("Client is shutting down.")
      self.continuation.yield(.shuttingDown)
      self.stop()
    }
    let task = Task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(100))
        continuation.yield(
          self.client.isActive() ? .connected : .disconnected
        )
      }
    }
    continuation.onTermination = { _ in
      task.cancel()
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

final class ConnectionManager: Sendable {
  private let client: MQTTClient
  private let logger: Logger?
  private let name: String
  private let shouldReconnect: Bool

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

  func connect(
    isolation: isolated (any Actor)? = #isolation,
    cleanSession: Bool
  ) async throws {
    do {
      try await client.connect(cleanSession: cleanSession)

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

      client.addShutdownListener(named: name) { [weak self] _ in
        self?.shutdown()
      }

    } catch {
      logger?.trace("Failed to connect: \(error)")
      throw error
    }
  }

  func shutdown(withLogging: Bool = true) {
    if withLogging {
      logger?.trace("Shutting down connection.")
    }
    client.removeCloseListener(named: name)
    client.removeShutdownListener(named: name)
  }
}
