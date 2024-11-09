import EnvVars
import Logging
import Models
import MQTTNIO
import NIO
import Psychrometrics
import ServiceLifecycle

// TODO: Pass in eventLoopGroup and MQTTClient.
public actor SensorsClient {

  public static let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  public let client: MQTTClient
  public private(set) var shuttingDown: Bool
  public private(set) var sensors: [TemperatureAndHumiditySensor]

  var logger: Logger { client.logger }

  public init(
    envVars: EnvVars,
    logger: Logger,
    sensors: [TemperatureAndHumiditySensor] = []
  ) {
    let config = MQTTClient.Configuration(
      version: .v3_1_1,
      userName: envVars.userName,
      password: envVars.password,
      useSSL: false,
      useWebSockets: false,
      tlsConfiguration: nil,
      webSocketURLPath: nil
    )
    self.client = MQTTClient(
      host: envVars.host,
      identifier: envVars.identifier,
      eventLoopGroupProvider: .shared(Self.eventLoopGroup),
      logger: logger,
      configuration: config
    )
    self.shuttingDown = false
    self.sensors = sensors
  }

  public func addSensor(_ sensor: TemperatureAndHumiditySensor) async throws {
    guard sensors.firstIndex(where: { $0.location == sensor.location }) == nil else {
      throw SensorExists()
    }
    sensors.append(sensor)
  }

  public func connect(cleanSession: Bool = true) async {
    do {
      try await client.connect(cleanSession: cleanSession)
      client.addCloseListener(named: "SensorsClient") { [self] _ in
        guard !self.shuttingDown else { return }
        Task {
          self.logger.debug("Connection closed.")
          self.logger.debug("Reconnecting...")
          await self.connect()
        }
      }
      logger.debug("Connection successful.")
    } catch {
      logger.trace("Connection Failed.\n\(error)")
    }
  }

  public func start() async throws {
    await withGracefulShutdownHandler {
      await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { try await self.subscribeToSensors() }
        group.addTask { try await self.addSensorListeners() }
      }
    } onGracefulShutdown: {
      Task { await self.shutdown() }
    }
//     do {
//       try await subscribeToSensors()
//       try await addSensorListeners()
//       logger.debug("Begin listening to sensors...")
//     } catch {
//       logger.trace("Error:\n(error)")
//       throw error
//     }
  }

  public func shutdown() async {
    shuttingDown = true
    try? await client.disconnect()
    try? await client.shutdown()
  }

  /// Subscribe to changes of the temperature and humidity sensors.
  func subscribeToSensors(qos: MQTTQoS = .exactlyOnce) async throws {
    for sensor in sensors {
      try await client.subscribeToSensor(sensor, qos: qos)
    }
  }

  private func _addSensorListeners(qos _: MQTTQoS = .exactlyOnce) async throws {
    // try await withThrowingDiscardingTaskGroup { group in
    // group.addTask { try await self.subscribeToSensors(qos: qos) }

    for await result in client.createPublishListener() {
      switch result {
      case let .failure(error):
        logger.trace("Error:\n\(error)")
      case let .success(value):
        let topic = value.topicName
        logger.trace("Received new value for topic: \(topic)")
        if topic.contains("temperature") {
          // do something.
          var buffer = value.payload
          guard let temperature = Temperature(buffer: &buffer) else {
            logger.trace("Decoding error for topic: \(topic)")
            throw DecodingError()
          }
          try sensors.update(topic: topic, keyPath: \.temperature, with: temperature)
          // group.addTask {
          Task {
            try await self.publishUpdates()
          }

        } else if topic.contains("humidity") {
          var buffer = value.payload
          // Decode and update the temperature value
          guard let humidity = RelativeHumidity(buffer: &buffer) else {
            logger.debug("Failed to decode humidity from buffer: \(buffer)")
            throw DecodingError()
          }
          try sensors.update(topic: topic, keyPath: \.humidity, with: humidity)
          //      group.addTask {
          Task {
            try await self.publishUpdates()
          }
        }
        //   }
      }
    }
  }

  func addSensorListeners(qos: MQTTQoS = .exactlyOnce) async throws {
    try await subscribeToSensors(qos: qos)
    client.addPublishListener(named: "SensorsClient") { result in
      do {
        switch result {
        case let .success(value):
          var buffer = value.payload
          let topic = value.topicName
          self.logger.trace("Received new value for topic: \(topic)")

          if topic.contains("temperature") {
            // Decode and update the temperature value
            guard let temperature = Temperature(buffer: &buffer) else {
              self.logger.debug("Failed to decode temperature from buffer: \(buffer)")
              throw DecodingError()
            }
            try self.sensors.update(topic: topic, keyPath: \.temperature, with: temperature)
            Task { try await self.publishUpdates() }
          } else if topic.contains("humidity") {
            // Decode and update the temperature value
            guard let humidity = RelativeHumidity(buffer: &buffer) else {
              self.logger.debug("Failed to decode humidity from buffer: \(buffer)")
              throw DecodingError()
            }
            try self.sensors.update(topic: topic, keyPath: \.humidity, with: humidity)
            Task { try await self.publishUpdates() }
          }

        case let .failure(error):
          self.logger.trace("Error:\n\(error)")
          throw error
        }
      } catch {
        self.logger.trace("Error:\n\(error)")
      }
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
      try await publish(double: sensor.dewPoint?.rawValue, to: sensor.topics.dewPoint)
      try await publish(double: sensor.enthalpy?.rawValue, to: sensor.topics.enthalpy)
      try sensors.hasProcessed(sensor)
    }
  }
}

// MARK: - Helpers

private extension MQTTClient {

  func subscribeToSensor(
    _ sensor: TemperatureAndHumiditySensor,
    qos: MQTTQoS = .exactlyOnce
  ) async throws {
    do {
      _ = try await subscribe(to: [
        MQTTSubscribeInfo(topicFilter: sensor.topics.temperature, qos: qos),
        MQTTSubscribeInfo(topicFilter: sensor.topics.humidity, qos: qos)
      ])
      logger.debug("Subscribed to temperature-humidity sensor: \(sensor.id)")
    } catch {
      logger.trace("Failed to subscribe to temperature-humidity sensor: \(sensor.id)")
      throw error
    }
  }
}

struct DecodingError: Error {}
struct NotFoundError: Error {}
struct SensorExists: Error {}

private extension TemperatureAndHumiditySensor.Topics {
  func contains(_ topic: String) -> Bool {
    temperature == topic || humidity == topic
  }
}

// TODO: Move to dewpoint-controller/main.swift
public extension Array where Element == TemperatureAndHumiditySensor {
  static var live: Self {
    TemperatureAndHumiditySensor.Location.allCases.map {
      TemperatureAndHumiditySensor(location: $0)
    }
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
