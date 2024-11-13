import Foundation
import Logging
@_exported import MQTTConnectionService
import MQTTNIO

public extension MQTTConnectionManager {
  static func live(
    client: MQTTClient,
    cleanSession: Bool = false,
    logger: Logger? = nil
  ) -> Self {
    let manager = ConnectionManager(client: client, logger: logger)
    return .init {
      try await manager.connect(cleanSession: cleanSession)

      return manager.stream
        .removeDuplicates()
        .eraseToStream()

    } shutdown: {
      manager.shutdown()
    }
  }
}

// MARK: - Helpers

final class MQTTConnectionStream: Sendable {
  private let client: MQTTClient
  private let continuation: AsyncStream<MQTTConnectionManager.Event>.Continuation
  private var logger: Logger { client.logger }
  private let name: String
  private let stream: AsyncStream<MQTTConnectionManager.Event>

  init(client: MQTTClient) {
    let (stream, continuation) = AsyncStream<MQTTConnectionManager.Event>.makeStream()
    self.client = client
    self.continuation = continuation
    self.name = UUID().uuidString
    self.stream = stream
    continuation.yield(client.isActive() ? .connected : .disconnected)
  }

  deinit { stop() }

  func start() -> AsyncStream<MQTTConnectionManager.Event> {
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

}

// TODO: Remove stream stuff from this.

private actor ConnectionManager {
  private let client: MQTTClient
  private let continuation: AsyncStream<MQTTConnectionManager.Event>.Continuation
  private nonisolated let logger: Logger?
  private let name: String
  private var started: Bool = false
  let stream: AsyncStream<MQTTConnectionManager.Event>

  init(
    client: MQTTClient,
    logger: Logger?
  ) {
    let (stream, continuation) = AsyncStream<MQTTConnectionManager.Event>.makeStream()
    self.client = client
    self.continuation = continuation
    self.logger = logger
    self.name = UUID().uuidString
    self.stream = stream
  }

  deinit {
    client.removeCloseListener(named: name)
    client.removeShutdownListener(named: name)
  }

  func connect(cleanSession: Bool) async throws {
    do {
      try await client.connect(cleanSession: cleanSession)

      continuation.yield(.connected)

      client.addCloseListener(named: name) { _ in
        self.continuation.yield(.disconnected)
        self.logger?.debug("Connection closed.")
        self.logger?.debug("Reconnecting...")
        Task { try await self.connect(cleanSession: cleanSession) }
      }

      client.addShutdownListener(named: name) { _ in
        self.shutdown()
      }

    } catch {
      client.logger.trace("Failed to connect: \(error)")
      continuation.yield(.disconnected)
      throw error
    }
  }

  nonisolated func shutdown() {
    client.logger.trace("Shutting down connection.")
    client.removeCloseListener(named: name)
    client.removeShutdownListener(named: name)
    continuation.yield(.shuttingDown)
    continuation.finish()
  }
}
