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

  /// Create an async stream that listens for changes to the given topics.
  private var _listen: @Sendable (_ topics: [String]) async throws -> AsyncThrowingStream<MQTTPublishInfo, any Error>

  /// Shutdown the listener stream.
  public var shutdown: @Sendable () -> Void

  /// Create a new topic listener.
  ///
  /// - Parameters:
  ///   - listen: Generate an async stream of changes for the given topics.
  ///   - shutdown: Shutdown the topic listener stream.
  public init(
    listen: @Sendable @escaping ([String]) async throws -> AsyncThrowingStream<MQTTPublishInfo, any Error>,
    shutdown: @Sendable @escaping () -> Void
  ) {
    self._listen = listen
    self.shutdown = shutdown
  }

  /// Create an async stream that listens for changes to the given topics.
  ///
  /// - Parameters:
  ///   - topics: The topics to listen for changes to.
  public func listen(to topics: [String]) async throws -> AsyncThrowingStream<MQTTPublishInfo, any Error> {
    try await _listen(topics)
  }

  /// Create an async stream that listens for changes to the given topics.
  ///
  /// - Parameters:
  ///   - topics: The topics to listen for changes to.
  public func listen(_ topics: String...) async throws -> AsyncThrowingStream<MQTTPublishInfo, any Error> {
    try await listen(to: topics)
  }

  /// Create the live implementation of the topic listener with the given MQTTClient.
  ///
  /// - Parameters:
  ///   - client: The MQTTClient to use.
  public static func live(client: MQTTClient) -> Self {
    let listener = MQTTTopicListener(client: client)
    return .init(
      listen: { await listener.listen($0) },
      shutdown: { listener.shutdown() }
    )
  }
}

extension TopicListener: TestDependencyKey {
  public static var testValue: TopicListener {
    Self()
  }
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
  private let continuation: AsyncThrowingStream<MQTTPublishInfo, any Error>.Continuation
  private let name: String
  let stream: AsyncThrowingStream<MQTTPublishInfo, any Error>
  private var shuttingDown: Bool = false

  init(
    client: MQTTClient
  ) {
    let (stream, continuation) = AsyncThrowingStream<MQTTPublishInfo, any Error>.makeStream()
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
  }

  func listen(_ topics: [String]) async -> AsyncThrowingStream<MQTTPublishInfo, any Error> {
    assert(client.isActive(), "The client is not connected.")
    client.addPublishListener(named: name) { result in
      switch result {
      case let .failure(error):
        self.client.logger.error("Received error while listening: \(error)")
        self.continuation.yield(with: .failure(error))
      case let .success(publishInfo):
        if topics.contains(publishInfo.topicName) {
          self.client.logger.trace("Recieved new value for topic: \(publishInfo.topicName)")
          self.continuation.yield(publishInfo)
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
    Task { await self.setIsShuttingDown() }
  }
}
