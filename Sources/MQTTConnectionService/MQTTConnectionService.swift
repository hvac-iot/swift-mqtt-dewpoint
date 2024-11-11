@preconcurrency import Foundation
import Logging
import Models
import MQTTNIO
import NIO
import ServiceLifecycle

// TODO: This may not need to be an actor.

/// Manages the MQTT broker connection.
public actor MQTTConnectionService: Service {

  private let cleanSession: Bool
  public let client: MQTTClient
  private let continuation: AsyncStream<Event>.Continuation
  public nonisolated let events: AsyncStream<Event>
  private let internalEventStream: ConnectionStream
  nonisolated var logger: Logger { client.logger }
  // private var shuttingDown = false

  public init(
    cleanSession: Bool = true,
    client: MQTTClient
  ) {
    self.cleanSession = cleanSession
    self.client = client
    self.internalEventStream = .init()
    let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
    self.events = stream
    self.continuation = continuation
  }

  deinit {
    self.logger.debug("MQTTConnectionService is gone.")
    self.internalEventStream.stop()
    continuation.finish()
  }

  /// The entry-point of the service.
  ///
  /// This method connects to the MQTT broker and manages the connection.
  /// It will attempt to gracefully shutdown the connection upon receiving
  /// `sigterm` signals.
  public func run() async throws {
    await withGracefulShutdownHandler {
      await withDiscardingTaskGroup { group in
        group.addTask { await self.connect() }
        group.addTask {
          await self.internalEventStream.start { self.client.isActive() }
        }
        for await event in self.internalEventStream.events.cancelOnGracefulShutdown() {
          if event == .shuttingDown {
            self.shutdown()
            break
          }
          self.logger.trace("Sending connection event: \(event)")
          self.continuation.yield(event)
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
      try await withThrowingDiscardingTaskGroup { group in
        group.addTask {
          try await self.client.connect(cleanSession: self.cleanSession)
        }
        client.addCloseListener(named: "\(Self.self)") { _ in
          Task {
            self.logger.debug("Connection closed.")
            self.logger.debug("Reconnecting...")
            await self.connect()
          }
        }
        self.logger.debug("Connection successful.")
        self.continuation.yield(.connected)
      }
    } catch {
      logger.trace("Failed to connect: \(error)")
      continuation.yield(.disconnected)
    }
  }

  private nonisolated func shutdown() {
    logger.debug("Begin shutting down MQTT broker connection.")
    client.removeCloseListener(named: "\(Self.self)")
    internalEventStream.stop()
    _ = client.disconnect()
    try? client.syncShutdownGracefully()
    continuation.finish()
    logger.info("MQTT broker connection closed.")
  }

}

extension MQTTConnectionService {

  public enum Event: Sendable {
    case connected
    case disconnected
    case shuttingDown
  }

  // TODO: This functionality can probably move into the connection service.

  private final class ConnectionStream: Sendable {

    // private var cancellable: AnyCancellable?
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
//       cancellable = Timer.publish(every: 1.0, on: .main, in: .common)
//         .autoconnect()
//         .sink { [weak self] (_: Date) in
//           let event: MQTTConnectionService.Event = connectionIsActive()
//             ? .connected
//             : .disconnected
//
//           self?.continuation.yield(event)
//         }
    }

    func stop() {
      continuation.yield(.shuttingDown)
      continuation.finish()
    }
  }

}
