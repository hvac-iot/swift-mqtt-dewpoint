import Foundation
import Logging
import Models
@preconcurrency import MQTTNIO
import NIO
import PsychrometricClient
import ServiceLifecycle

public actor SensorsService: Service {
  private var sensors: [TemperatureAndHumiditySensor]
  private let client: MQTTClient
  var logger: Logger { client.logger }

  public init(
    client: MQTTClient,
    sensors: [TemperatureAndHumiditySensor]
  ) {
    self.client = client
    self.sensors = sensors
  }

  /// The entry-point of the service.
  ///
  /// This method is called to start the service and begin
  /// listening for sensor value changes then publishing the dew-point
  /// and enthalpy values of the sensors.
  public func run() async throws {
    guard client.isActive() else {
      throw MQTTClientNotConnected()
    }
    try await withThrowingDiscardingTaskGroup { group in
      group.addTask { try await self.subscribeToSensors() }
      for await result in client.createPublishListener().cancelOnGracefulShutdown() {
        group.addTask {
          try await self.handleResult(result)
        }
      }
    }
  }

  private func handleResult(
    _ result: Result<MQTTPublishInfo, any Error>
  ) async throws {
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

  private func publish(double: Double?, to topic: String) async throws {
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
