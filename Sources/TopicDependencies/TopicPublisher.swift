import Dependencies
import DependenciesMacros
import MQTTNIO
import NIO

/// A dependency that is responsible for publishing values to an MQTT broker.
///
/// - Note: This dependency only conforms to `TestDependencyKey` because it
/// requires an active `MQTTClient` to generate the live dependency.
@DependencyClient
public struct TopicPublisher: Sendable {

  private var _publish: @Sendable (PublishRequest) async throws -> Void

  /// Create a new topic publisher.
  ///
  /// - Parameters:
  ///   -  publish: Handle the publish request.
  public init(
    publish: @Sendable @escaping (PublishRequest) async throws -> Void
  ) {
    self._publish = publish
  }

  /// Publish a new value to the given topic.
  ///
  /// - Parameters:
  ///   - topicName: The topic to publish the new value to.
  ///   - payload: The value to publish.
  ///   - qos: The MQTTQoS.
  ///   - retain: The retain flag.
  public func publish(
    to topicName: String,
    payload: ByteBuffer,
    qos: MQTTQoS,
    retain: Bool = false
  ) async throws {
    try await _publish(.init(
      topicName: topicName,
      payload: payload,
      qos: qos,
      retain: retain
    ))
  }

  /// Create the live topic publisher with the given `MQTTClient`.
  ///
  /// - Parameters:
  ///   - client: The mqtt broker client to use.
  public static func live(client: MQTTClient) -> Self {
    .init(
      publish: { request in
        assert(client.isActive(), "Client not connected.")
        client.logger.trace("Begin publishing to topic: \(request.topicName)")
        defer { client.logger.trace("Done publishing to topic: \(request.topicName)") }
        try await client.publish(
          to: request.topicName,
          payload: request.payload,
          qos: request.qos,
          retain: request.retain
        )
      }
    )
  }

  /// Represents the parameters required to publish a new value to the
  /// MQTT broker.
  public struct PublishRequest: Equatable, Sendable {

    /// The topic to publish the new value to.
    public let topicName: String

    /// The value to publish.
    public let payload: ByteBuffer

    /// The qos of the request.
    public let qos: MQTTQoS

    /// The retain flag for the request.
    public let retain: Bool

    /// Create a new publish request.
    ///
    /// - Parameters:
    ///   - topicName: The topic to publish to.
    ///   - payload: The value to publish.
    ///   - qos: The qos of the request.
    ///   - retain: The retain flag of the request.
    public init(
      topicName: String,
      payload: ByteBuffer,
      qos: MQTTQoS,
      retain: Bool
    ) {
      self.topicName = topicName
      self.payload = payload
      self.qos = qos
      self.retain = retain
    }
  }
}

extension TopicPublisher: TestDependencyKey {
  public static var testValue: TopicPublisher { Self() }
}

public extension DependencyValues {

  /// A dependency that is responsible for publishing values to an MQTT broker.
  var topicPublisher: TopicPublisher {
    get { self[TopicPublisher.self] }
    set { self[TopicPublisher.self] = newValue }
  }
}
