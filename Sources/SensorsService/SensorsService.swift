import Dependencies
import DependenciesMacros
import Foundation
import Logging
import Models
import NIO
import PsychrometricClient
import ServiceLifecycle

/// Represents the interface required for the sensor service to operate.
///
/// This allows the dependency to be controlled for testing purposes and
/// not rely on an active MQTT broker connection.
///
/// For the live implementation see ``SensorsClientLive`` module.
///
@DependencyClient
public struct SensorsClient: Sendable {

  public typealias PublishInfo = (buffer: ByteBuffer, topic: String)

  /// Start listening for changes to sensor values on the MQTT broker.
  public var listen: @Sendable ([String]) async throws -> AsyncStream<PublishInfo>

  /// Publish dew-point or enthalpy values back to the MQTT broker.
  public var publish: @Sendable (Double, String) async throws -> Void

  /// Shutdown the service.
  public var shutdown: @Sendable () -> Void = {}

  /// Start listening for changes to sensor values on the MQTT broker.
  public func listen(to topics: [String]) async throws -> AsyncStream<PublishInfo> {
    try await listen(topics)
  }

  /// Publish dew-point or enthalpy values back to the MQTT broker.
  public func publish(_ value: Double, to topic: String) async throws {
    try await publish(value, topic)
  }
}

extension SensorsClient: TestDependencyKey {
  public static var testValue: SensorsClient {
    Self()
  }
}

public extension DependencyValues {
  var sensorsClient: SensorsClient {
    get { self[SensorsClient.self] }
    set { self[SensorsClient.self] = newValue }
  }
}

// MARK: - SensorsService

/// Service that is responsible for listening to changes of the temperature and humidity
/// sensors, then publishing back the calculated dew-point temperature and enthalpy for
/// the sensor location.
///
///
public actor SensorsService: Service {

  @Dependency(\.sensorsClient) var client

  private var sensors: [TemperatureAndHumiditySensor]

  private let logger: Logger?

  /// Create a new sensors service that listens to the passed in
  /// sensors.
  ///
  /// - Note: The service will fail to start if the array of sensors is not greater than 0.
  ///
  /// - Parameters:
  ///   - sensors: The sensors to listen for changes to.
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
    precondition(sensors.count > 0)

    let stream = try await client.listen(to: topics)

    await withGracefulShutdownHandler {
      await withDiscardingTaskGroup { group in
        for await result in stream {
          group.addTask { await self.handleResult(result) }
        }
      }
    } onGracefulShutdown: {
      Task {
        self.logger?.trace("Received graceful shutdown.")
        try? await self.publishUpdates()
        await self.client.shutdown()
      }
    }
  }

  private var topics: [String] {
    sensors.reduce(into: [String]()) { array, sensor in
      array.append(sensor.topics.temperature)
      array.append(sensor.topics.humidity)
    }
  }

  private func handleResult(_ result: SensorsClient.PublishInfo) async {
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
    try await client.publish(double, to: topic)
    logger?.trace("Published update to topic: \(topic)")
  }

  private func publishUpdates() async throws {
    for sensor in sensors.filter(\.needsProcessed) {
      try await publish(sensor.dewPoint?.value, to: sensor.topics.dewPoint)
      try await publish(sensor.enthalpy?.value, to: sensor.topics.enthalpy)
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
