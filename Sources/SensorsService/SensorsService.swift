import Dependencies
import DependenciesMacros
import Foundation
import Logging
import Models
import MQTTConnectionService
@preconcurrency import MQTTNIO
import NIO
import PsychrometricClient
import ServiceLifecycle

@DependencyClient
public struct SensorsClient: Sendable {

  public var listen: @Sendable ([String]) async throws -> AsyncStream<MQTTPublishInfo>
  public var logger: Logger?
  public var publish: @Sendable (Double, String) async throws -> Void
  public var shutdown: @Sendable () -> Void = {}

  public func listen(to topics: [String]) async throws -> AsyncStream<MQTTPublishInfo> {
    try await listen(topics)
  }

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

public actor SensorsService2: Service {

  @Dependency(\.sensorsClient) var client

  private var sensors: [TemperatureAndHumiditySensor]

  public init(
    sensors: [TemperatureAndHumiditySensor]
  ) {
    self.sensors = sensors
  }

  public func run() async throws {
    guard sensors.count > 0 else {
      throw SensorCountError()
    }

    let stream = try await client.listen(to: topics)

    do {
      try await withGracefulShutdownHandler {
        try await withThrowingDiscardingTaskGroup { group in
          for await result in stream.cancelOnGracefulShutdown() {
            group.addTask { try await self.handleResult(result) }
          }
        }
      } onGracefulShutdown: {
        Task {
          await self.client.logger?.trace("Received graceful shutdown.")
          try? await self.publishUpdates()
          await self.client.shutdown()
        }
      }
    } catch {
      client.logger?.trace("Error: \(error)")
      client.shutdown()
    }
  }

  private var topics: [String] {
    sensors.reduce(into: [String]()) { array, sensor in
      array.append(sensor.topics.temperature)
      array.append(sensor.topics.humidity)
    }
  }

  private func handleResult(_ result: MQTTPublishInfo) async throws {
    let topic = result.topicName
    client.logger?.trace("Begin handling result for topic: \(topic)")

    func decode<V: BufferInitalizable>(_: V.Type) -> V? {
      var buffer = result.payload
      return V(buffer: &buffer)
    }

    if topic.contains("temperature") {
      client.logger?.trace("Begin handling temperature result.")
      guard let temperature = decode(DryBulb.self) else {
        client.logger?.trace("Failed to decode temperature: \(result.payload)")
        throw DecodingError()
      }
      client.logger?.trace("Decoded temperature: \(temperature)")
      try sensors.update(topic: topic, keyPath: \.temperature, with: temperature)

    } else if topic.contains("humidity") {
      client.logger?.trace("Begin handling humidity result.")
      guard let humidity = decode(RelativeHumidity.self) else {
        client.logger?.trace("Failed to decode humidity: \(result.payload)")
        throw DecodingError()
      }
      client.logger?.trace("Decoded humidity: \(humidity)")
      try sensors.update(topic: topic, keyPath: \.humidity, with: humidity)
    } else {
      client.logger?.error("Received unexpected topic, expected topic to contain 'temperature' or 'humidity'!")
      return
    }

    try await publishUpdates()
    client.logger?.trace("Done handling result for topic: \(topic)")
  }

  private func publish(_ double: Double?, to topic: String) async throws {
    guard let double else { return }
    try await client.publish(double, to: topic)
    client.logger?.trace("Published update to topic: \(topic)")
  }

  private func publishUpdates() async throws {
    for sensor in sensors.filter(\.needsProcessed) {
      try await publish(sensor.dewPoint?.value, to: sensor.topics.dewPoint)
      try await publish(sensor.enthalpy?.value, to: sensor.topics.enthalpy)
    }
  }
}

public actor SensorsService: Service {
  private var sensors: [TemperatureAndHumiditySensor]
  private let client: MQTTClient
  private let events: @Sendable () -> AsyncStream<MQTTConnectionService.Event>
  nonisolated var logger: Logger { client.logger }
  private var shuttingDown: Bool = false

  public init(
    client: MQTTClient,
    events: @Sendable @escaping () -> AsyncStream<MQTTConnectionService.Event>,
    sensors: [TemperatureAndHumiditySensor]
  ) {
    self.client = client
    self.events = events
    self.sensors = sensors
  }

  /// The entry-point of the service.
  ///
  /// This method is called to start the service and begin
  /// listening for sensor value changes then publishing the dew-point
  /// and enthalpy values of the sensors.
  public func run() async throws {
    do {
      try await withGracefulShutdownHandler {
        try await withThrowingDiscardingTaskGroup { group in
          client.addPublishListener(named: "\(Self.self)") { result in
            if self.shuttingDown {
              self.logger.trace("Shutting down.")
            } else if !self.client.isActive() {
              self.logger.trace("Client is not currently active")
            } else {
              Task { try await self.handleResult(result) }
            }
          }
          for await event in self.events().cancelOnGracefulShutdown() {
            logger.trace("Received event: \(event)")
            if event == .shuttingDown {
              self.setIsShuttingDown()
            } else if event == .connected {
              group.addTask { try await self.subscribeToSensors() }
            } else {
              group.addTask { await self.unsubscribeToSensors() }
              group.addTask { try? await Task.sleep(for: .milliseconds(100)) }
            }
          }
        }
      } onGracefulShutdown: {
        // do something.
        self.logger.debug("Received graceful shutdown.")
        Task { [weak self] in await self?.setIsShuttingDown() }
      }
    } catch {
      // WARN: We always get an MQTTNIO `noConnection` error here, which generally is not an issue,
      // but causes service ServiceLifecycle to fail, so currently just ignoring errors that are thrown.
      // However we do receive the unsubscribe message back from the MQTT broker, so it is likely safe
      // to ignore the `noConnection` error.
      logger.trace("Run error: \(error)")
      // throw error
    }
  }

  private func setIsShuttingDown() {
    logger.debug("Received shut down event.")
    Task { try await publishUpdates() }
    Task { await self.unsubscribeToSensors() }
    shuttingDown = true
    client.removePublishListener(named: "\(Self.self)")
  }

  private func handleResult(
    _ result: Result<MQTTPublishInfo, any Error>
  ) async throws {
    logger.trace("Begin handling result")
    do {
      switch result {
      case let .failure(error):
        logger.debug("Failed receiving sensor: \(error)")
        throw error
      case let .success(value):
        // do something.
        let topic = value.topicName
        logger.trace("Received new value for topic: \(topic)")
        if topic.contains("temperature") {
          // do something.
          var buffer = value.payload
          guard let temperature = DryBulb(buffer: &buffer) else {
            logger.trace("Decoding error for topic: \(topic)")
            throw DecodingError()
          }
          try sensors.update(topic: topic, keyPath: \.temperature, with: temperature)
          try await publishUpdates()

        } else if topic.contains("humidity") {
          var buffer = value.payload
          // Decode and update the temperature value
          guard let humidity = RelativeHumidity(buffer: &buffer) else {
            logger.debug("Failed to decode humidity from buffer: \(buffer)")
            throw DecodingError()
          }
          try sensors.update(topic: topic, keyPath: \.humidity, with: humidity)
          try await publishUpdates()
        }
      }
    } catch {
      logger.trace("Handle Result error: \(error)")
      throw error
    }
  }

  private func subscribeToSensors() async throws {
    for sensor in sensors {
      _ = try await client.subscribe(to: [
        MQTTSubscribeInfo(topicFilter: sensor.topics.temperature, qos: .atLeastOnce),
        MQTTSubscribeInfo(topicFilter: sensor.topics.humidity, qos: .atLeastOnce)
      ])
      logger.debug("Subscribed to sensor: \(sensor.location)")
    }
  }

  private func unsubscribeToSensors() async {
    logger.trace("Begin unsubscribe to sensors.")
    guard client.isActive() else {
      logger.debug("Client is not active, skipping.")
      return
    }
    do {
      let topics = sensors.reduce(into: [String]()) { array, sensor in
        array.append(sensor.topics.temperature)
        array.append(sensor.topics.humidity)
      }
      try await client.unsubscribe(from: topics)
      logger.trace("Unsubscribed from sensors.")
    } catch {
      logger.trace("Unsubscribe error: \(error)")
    }
  }

  private func publish(double: Double?, to topic: String) async throws {
    guard client.isActive() else { return }
    guard let double else { return }
    let rounded = round(double * 100) / 100
    logger.debug("Publishing \(rounded), to: \(topic)")
    try await client.publish(
      to: topic,
      payload: ByteBufferAllocator().buffer(string: "\(rounded)"),
      qos: .exactlyOnce,
      retain: true
    )
  }

  private func publishUpdates() async throws {
    for sensor in sensors.filter(\.needsProcessed) {
      try await publish(double: sensor.dewPoint?.value, to: sensor.topics.dewPoint)
      try await publish(double: sensor.enthalpy?.value, to: sensor.topics.enthalpy)
      try sensors.hasProcessed(sensor)
    }
  }

}

// MARK: - Errors

struct DecodingError: Error {}
struct MQTTClientNotConnected: Error {}
struct NotFoundError: Error {}
struct SensorExists: Error {}
struct SensorCountError: Error {}

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
      throw NotFoundError()
    }
    self[index][keyPath: keyPath] = value
  }

  mutating func hasProcessed(_ sensor: TemperatureAndHumiditySensor) throws {
    guard let index = firstIndex(where: { $0.id == sensor.id }) else {
      throw NotFoundError()
    }
    self[index].needsProcessed = false
  }
}
