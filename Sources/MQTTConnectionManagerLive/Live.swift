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
    return .init { _ in
      try await manager.connect(cleanSession: cleanSession)
      return manager.stream
    } shutdown: {
      manager.shutdown()
    }
  }
}

// MARK: - Helpers

private actor ConnectionManager {
  private let client: MQTTClient
  private let continuation: AsyncStream<MQTTConnectionManager.Event>.Continuation
  private nonisolated let logger: Logger?
  private let name: String
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
  }

  func connect(cleanSession: Bool) async throws {
    do {
      try await client.connect(cleanSession: cleanSession)

      continuation.yield(.connected)

      client.addCloseListener(named: name) { _ in
        Task {
          self.continuation.yield(.disconnected)
          self.logger?.debug("Connection closed.")
          self.logger?.debug("Reconnecting...")
          try await self.connect(cleanSession: cleanSession)
        }
      }
    } catch {
      client.logger.trace("Failed to connect: \(error)")
      continuation.yield(.disconnected)
      throw error
    }
  }

  nonisolated func shutdown() {
    continuation.yield(.shuttingDown)
    continuation.finish()
  }
}
