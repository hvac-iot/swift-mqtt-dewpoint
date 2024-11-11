import Foundation
import Logging
import Models
import MQTTNIO
import NIO
import ServiceLifecycle

/// Manages the MQTT broker connection.
public actor MQTTConnectionService: Service {

  private let cleanSession: Bool
  private let client: MQTTClient
  private let internalEventStream: ConnectionStream
  nonisolated var logger: Logger { client.logger }
  private let name: String

  public init(
    cleanSession: Bool = true,
    client: MQTTClient
  ) {
    self.cleanSession = cleanSession
    self.client = client
    self.internalEventStream = .init()
    self.name = UUID().uuidString
  }

  deinit {
    self.logger.debug("MQTTConnectionService is gone.")
    self.internalEventStream.stop()
  }

  /// The entry-point of the service.
  ///
  /// This method connects to the MQTT broker and manages the connection.
  /// It will attempt to gracefully shutdown the connection upon receiving
  /// a shutdown signals.
  public func run() async throws {
    await withGracefulShutdownHandler {
      await withDiscardingTaskGroup { group in
        group.addTask { await self.connect() }
        group.addTask {
          await self.internalEventStream.start { self.client.isActive() }
        }
        for await event in self.internalEventStream.events.cancelOnGracefulShutdown() {
          if event == .shuttingDown {
            break
          }
          self.logger.trace("Sending connection event: \(event)")
        }
        group.cancelAll()
      }
    } onGracefulShutdown: {
      self.logger.trace("Received graceful shutdown.")
      self.shutdown()
    }
  }

  func connect() async {
    do {
      try await client.connect(cleanSession: cleanSession)
      client.addCloseListener(named: name) { _ in
        Task {
          self.logger.debug("Connection closed.")
          self.logger.debug("Reconnecting...")
          await self.connect()
        }
      }
      logger.debug("Connection successful.")
    } catch {
      logger.trace("Failed to connect: \(error)")
    }
  }

  private nonisolated func shutdown() {
    logger.debug("Begin shutting down MQTT broker connection.")
    client.removeCloseListener(named: name)
    internalEventStream.stop()
    _ = client.disconnect()
    try? client.syncShutdownGracefully()
    logger.info("MQTT broker connection closed.")
  }

}

extension MQTTConnectionService {

  public enum Event: Sendable {
    case connected
    case disconnected
    case shuttingDown
  }

  private actor ConnectionStream: Sendable {

    private let continuation: AsyncStream<MQTTConnectionService.Event>.Continuation
    let events: AsyncStream<MQTTConnectionService.Event>

    init() {
      let (stream, continuation) = AsyncStream.makeStream(of: MQTTConnectionService.Event.self)
      self.events = stream
      self.continuation = continuation
    }

    deinit {
      stop()
    }

    func start(isActive connectionIsActive: @escaping () -> Bool) async {
      try? await Task.sleep(for: .seconds(1))
      let event: MQTTConnectionService.Event = connectionIsActive()
        ? .connected
        : .disconnected

      continuation.yield(event)
    }

    nonisolated func stop() {
      continuation.yield(.shuttingDown)
      continuation.finish()
    }
  }

}
