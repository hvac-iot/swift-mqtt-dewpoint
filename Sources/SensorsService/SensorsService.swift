import Foundation
import Logging
import Models
import MQTTConnectionService
@preconcurrency import MQTTNIO
import NIO
import PsychrometricClient
import ServiceLifecycle

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
