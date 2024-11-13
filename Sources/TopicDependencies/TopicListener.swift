import Dependencies
import DependenciesMacros
import Foundation
import MQTTNIO

/// A dependency that can generate an async stream of changes to the given topics.
///
/// - Note: This type only conforms to ``TestDependencyKey`` because it requires an MQTTClient
/// to generate the live dependency.
@DependencyClient
public struct TopicListener: Sendable {

  public typealias Stream = AsyncStream<Result<MQTTPublishInfo, MQTTListenResultError>>

  /// Create an async stream that listens for changes to the given topics.
  private var _listen: @Sendable ([String], MQTTQoS) async throws -> Stream

  /// Shutdown the listener stream.
  public var shutdown: @Sendable () -> Void

  /// Create a new topic listener.
  ///
  /// - Parameters:
  ///   - listen: Generate an async stream of changes for the given topics.
  ///   - shutdown: Shutdown the topic listener stream.
  public init(
    listen: @Sendable @escaping ([String], MQTTQoS) async throws -> Stream,
    shutdown: @Sendable @escaping () -> Void
  ) {
    self._listen = listen
    self.shutdown = shutdown
  }

  /// Create an async stream that listens for changes to the given topics.
  ///
  /// - Parameters:
  ///   - topics: The topics to listen for changes to.
  ///   - qos: The MQTTQoS for the subscription.
  public func listen(
    to topics: [String],
    qos: MQTTQoS = .atLeastOnce
  ) async throws -> Stream {
    try await _listen(topics, qos)
  }

  /// Create an async stream that listens for changes to the given topics.
  ///
  /// - Parameters:
  ///   - topics: The topics to listen for changes to.
  ///   - qos: The MQTTQoS for the subscription.
  public func listen(
    _ topics: String...,
    qos: MQTTQoS = .atLeastOnce
  ) async throws -> Stream {
    try await listen(to: topics, qos: qos)
  }

  /// Create the live implementation of the topic listener with the given MQTTClient.
  ///
  /// - Parameters:
  ///   - client: The MQTTClient to use.
  public static func live(client: MQTTClient) -> Self {
    let listener = MQTTTopicListener(client: client)
    return .init(
      listen: { try await listener.listen($0, $1) },
      shutdown: { listener.shutdown() }
    )
  }
}

extension TopicListener: TestDependencyKey {
  public static var testValue: TopicListener { Self() }
}

public extension DependencyValues {
  var topicListener: TopicListener {
    get { self[TopicListener.self] }
    set { self[TopicListener.self] = newValue }
  }
}

// MARK: - Helpers

private actor MQTTTopicListener {
  private let client: MQTTClient
  private let continuation: TopicListener.Stream.Continuation
  private let name: String
  let stream: TopicListener.Stream
  private var shuttingDown: Bool = false

  init(
    client: MQTTClient
  ) {
    let (stream, continuation) = TopicListener.Stream.makeStream()
    self.client = client
    self.continuation = continuation
    self.name = UUID().uuidString
    self.stream = stream
  }

  deinit {
    if !shuttingDown {
      let message = """
      Shutdown was not called on topic listener. This could lead to potential errors or
      the stream never ending.

      Please ensure that you call shutdown on the listener.
      """
      client.logger.warning("\(message)")
      continuation.finish()
    }
    client.removePublishListener(named: name)
    client.removeShutdownListener(named: name)
  }

  func listen(
    _ topics: [String],
    _ qos: MQTTQoS = .atLeastOnce
  ) async throws(TopicListenerError) -> TopicListener.Stream {
    var sleepTimes = 0

    while !client.isActive() {
      guard sleepTimes < 10 else {
        throw .connectionTimeout
      }
      try? await Task.sleep(for: .milliseconds(100))
      sleepTimes += 1
    }

    client.logger.trace("Client is active, begin subscribing to topics.")

    let subscription = try? await client.subscribe(to: topics.map {
      MQTTSubscribeInfo(topicFilter: $0, qos: qos)
    })

    guard subscription != nil else {
      client.logger.error("Error subscribing to topics: \(topics)")
      throw .failedToSubscribe
    }

    client.logger.trace("Done subscribing, begin listening to topics.")

    client.addPublishListener(named: name) { result in
      switch result {
      case let .failure(error):
        self.client.logger.error("Received error while listening: \(error)")
        self.continuation.yield(.failure(.init(error)))
      case let .success(publishInfo):
        if topics.contains(publishInfo.topicName) {
          self.client.logger.trace("Recieved new value for topic: \(publishInfo.topicName)")
          self.continuation.yield(.success(publishInfo))
        }
      }
    }

    return stream
  }

  private func setIsShuttingDown() {
    shuttingDown = true
  }

  nonisolated func shutdown() {
    client.logger.trace("Closing topic listener...")
    continuation.finish()
    client.removePublishListener(named: name)
    client.removeShutdownListener(named: name)
    Task { await self.setIsShuttingDown() }
  }
}

public enum TopicListenerError: Error {
  case connectionTimeout
  case failedToSubscribe
}

public struct MQTTListenResultError: Error {
  let underlyingError: any Error

  init(_ underlyingError: any Error) {
    self.underlyingError = underlyingError
  }
}
