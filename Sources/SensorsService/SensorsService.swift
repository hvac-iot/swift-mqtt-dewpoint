import Dependencies
import DependenciesMacros
import Foundation
import Logging
import Models
import MQTTNIO
import NIO
import PsychrometricClient
import ServiceLifecycle
import TopicDependencies

/// Service that is responsible for listening to changes of the temperature and humidity
/// sensors, then publishing back the calculated dew-point temperature and enthalpy for
/// the sensor location.
///
///
public actor SensorsService: Service {

  @Dependency(\.topicListener) var topicListener
  @Dependency(\.topicPublisher) var topicPublisher

  /// The logger to use for the service.
  private let logger: Logger?

  /// The sensors that we are listening for updates to, so
  /// that we can calculate the dew-point temperature and enthalpy
  /// values to publish back to the MQTT broker.
  var sensors: [TemperatureAndHumiditySensor]

  var topics: [String] {
    sensors.reduce(into: [String]()) { array, sensor in
      array.append(sensor.topics.temperature)
      array.append(sensor.topics.humidity)
    }
  }

  /// Create a new sensors service that listens to the passed in
  /// sensors.
  ///
  /// - Note: The service will fail to start if the array of sensors is not greater than 0.
  ///
  /// - Parameters:
  ///   - sensors: The sensors to listen for changes to.
  ///   - logger: An optional logger to use.
  public init(
    sensors: [TemperatureAndHumiditySensor],
    logger: Logger? = nil
  ) {
    self.sensors = sensors
    self.logger = logger
  }

  /// Start the service with graceful shutdown, which will attempt to publish
  /// any pending changes to the MQTT broker, upon a shutdown signal.
  public func run() async throws {
    precondition(sensors.count > 0, "Sensors should not be empty.")

    let stream = try await makeStream()

    await withGracefulShutdownHandler {
      await withDiscardingTaskGroup { group in
        for await result in stream.cancelOnGracefulShutdown() {
          logger?.trace("Received result for topic: \(result.topic)")
          group.addTask { await self.handleResult(result) }
        }
        // group.cancelAll()
      }
    } onGracefulShutdown: {
      Task {
        self.logger?.trace("Received graceful shutdown.")
        try? await self.publishUpdates()
        await self.topicListener.shutdown()
      }
    }
  }

  private func makeStream() async throws -> AsyncStream<(buffer: ByteBuffer, topic: String)> {
    try await topicListener.listen(to: topics)
      // ignore errors, so that we continue to listen, but log them
      // for debugging purposes.
      .compactMap { result in
        switch result {
        case let .failure(error):
          self.logger?.trace("Received error listening for sensors: \(error)")
          return nil
        case let .success(info):
          return (info.payload, info.topicName)
        }
      }
      // ignore duplicate values, to prevent publishing dew-point and enthalpy
      // changes to frequently.
      .removeDuplicates { lhs, rhs in
        lhs.buffer == rhs.buffer
          && lhs.topic == rhs.topic
      }
      .eraseToStream()
  }

  private func handleResult(_ result: (buffer: ByteBuffer, topic: String)) async {
    do {
      let topic = result.topic
      assert(topics.contains(topic))
      logger?.trace("Begin handling result for topic: \(topic)")

      func decode<V: BufferInitalizable>(_: V.Type) -> V? {
        var buffer = result.buffer
        return V(buffer: &buffer)
      }

      if topic.contains("temperature") {
        logger?.trace("Begin handling temperature result.")
        guard let temperature = decode(DryBulb.self) else {
          logger?.trace("Failed to decode temperature: \(result.buffer)")
          throw DecodingError()
        }
        logger?.trace("Decoded temperature: \(temperature)")
        try sensors.update(topic: topic, keyPath: \.temperature, with: temperature)

      } else if topic.contains("humidity") {
        logger?.trace("Begin handling humidity result.")
        guard let humidity = decode(RelativeHumidity.self) else {
          logger?.trace("Failed to decode humidity: \(result.buffer)")
          throw DecodingError()
        }
        logger?.trace("Decoded humidity: \(humidity)")
        try sensors.update(topic: topic, keyPath: \.humidity, with: humidity)
      }

      try await publishUpdates()
      logger?.trace("Done handling result for topic: \(topic)")
    } catch {
      logger?.error("Received error: \(error)")
    }
  }

  private func publish(_ double: Double?, to topic: String) async throws {
    guard let double else { return }
    try await topicPublisher.publish(
      to: topic,
      payload: ByteBufferAllocator().buffer(string: "\(double)"),
      qos: .exactlyOnce,
      retain: true
    )
    logger?.trace("Published update to topic: \(topic)")
  }

  private func publishUpdates() async throws {
    for sensor in sensors.filter(\.needsProcessed) {
      try await publish(sensor.dewPoint?.value, to: sensor.topics.dewPoint)
      try await publish(sensor.enthalpy?.value, to: sensor.topics.enthalpy)
      try sensors.hasProcessed(sensor)
    }
  }
}

// MARK: - Errors

struct DecodingError: Error {}
struct SensorNotFoundError: Error {}

// MARK: - Helpers

private extension TemperatureAndHumiditySensor.Topics {
  func contains(_ topic: String) -> Bool {
    temperature == topic || humidity == topic
  }
}

private extension Array where Element == TemperatureAndHumiditySensor {

  mutating func update<V>(
    topic: String,
    keyPath: WritableKeyPath<TemperatureAndHumiditySensor, V>,
    with value: V
  ) throws {
    guard let index = firstIndex(where: { $0.topics.contains(topic) }) else {
      throw SensorNotFoundError()
    }
    self[index][keyPath: keyPath] = value
  }

  mutating func hasProcessed(_ sensor: TemperatureAndHumiditySensor) throws {
    guard let index = firstIndex(where: { $0.id == sensor.id }) else {
      throw SensorNotFoundError()
    }
    self[index].needsProcessed = false
  }
}
