import Dependencies
import Foundation
import MQTTNIO
import NIO
@_exported import SensorsService

public extension SensorsClient {

  /// Creates the live implementation of the sensor client.
  static func live(
    client: MQTTClient,
    publishQoS: MQTTQoS = .exactlyOnce,
    subscribeQoS: MQTTQoS = .atLeastOnce
  ) -> Self {
    let listener = SensorClientListener(
      client: client,
      publishQoS: publishQoS,
      subscribeQoS: subscribeQoS
    )

    return .init(
      listen: { try await listener.listen($0) },
      logger: client.logger,
      publish: { try await listener.publish($0, $1) },
      shutdown: { listener.shutdown() }
    )
  }
}

struct ConnectionTimeoutError: Error {}

private actor SensorClientListener {

  let client: MQTTClient
  private let continuation: AsyncStream<SensorsClient.PublishInfo>.Continuation
  let name: String
  let publishQoS: MQTTQoS
  let stream: AsyncStream<SensorsClient.PublishInfo>
  let subscribeQoS: MQTTQoS

  init(
    client: MQTTClient,
    publishQoS: MQTTQoS,
    subscribeQoS: MQTTQoS
  ) {
    let (stream, continuation) = AsyncStream<SensorsClient.PublishInfo>.makeStream()
    self.client = client
    self.continuation = continuation
    self.name = UUID().uuidString
    self.publishQoS = publishQoS
    self.stream = stream
    self.subscribeQoS = subscribeQoS
  }

  deinit {
    client.logger.trace("Sensor listener is gone.")
    self.client.removeCloseListener(named: name)
    self.client.removePublishListener(named: name)
  }

  func listen(_ topics: [String]) async throws -> AsyncStream<SensorsClient.PublishInfo> {
    client.logger.trace("Begin listen...")
    // Ensure we are subscribed to the topics.
    var sleepTimes = 0

    while !client.isActive() {
      guard sleepTimes < 10 else {
        throw ConnectionTimeoutError()
      }
      try await Task.sleep(for: .milliseconds(100))
      sleepTimes += 1
    }

    client.logger.trace("Connection is active, begin listening for updates.")
    client.logger.trace("Topics: \(topics)")

    _ = try await client.subscribe(to: topics.map { topic in
      MQTTSubscribeInfo(topicFilter: topic, qos: subscribeQoS)
    })

    client.logger.trace("Done subscribing to topics.")

    client.addPublishListener(named: name) { result in
      self.client.logger.trace("Received new result...")
      switch result {
      case let .failure(error):
        self.client.logger.error("Received error while listening: \(error)")
      case let .success(publishInfo):
        // Only publish values back to caller if they are listening to a
        // the topic.
        if topics.contains(publishInfo.topicName) {
          self.client.logger.trace("Recieved published info for: \(publishInfo.topicName)")
          self.continuation.yield((buffer: publishInfo.payload, topic: publishInfo.topicName))
        } else {
          self.client.logger.trace("Skipping topic: \(publishInfo.topicName)")
        }
      }
    }

    client.addShutdownListener(named: name) { _ in
      self.continuation.finish()
    }

    return stream
  }

  func publish(_ double: Double, _ topic: String) async throws {
    // Ensure the client is active before publishing values.
    guard client.isActive() else { return }

    // Round the double and publish.
    let rounded = round(double * 100) / 100
    client.logger.trace("Begin publishing: \(rounded) to: \(topic)")
    try await client.publish(
      to: topic,
      payload: ByteBufferAllocator().buffer(string: "\(rounded)"),
      qos: publishQoS,
      retain: true
    )
    client.logger.trace("Begin publishing: \(rounded) to: \(topic)")
  }

  nonisolated func shutdown() {
    continuation.finish()
  }

}
