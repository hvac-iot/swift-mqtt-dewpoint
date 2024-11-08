import EnvVars
import Logging
import Models
import MQTTNIO
import NIO
import Psychrometrics

public class AsyncClient {

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

  public func addSensor(_ sensor: TemperatureAndHumiditySensor) throws {
    guard sensors.firstIndex(where: { $0.location == sensor.location }) == nil else {
      throw SensorExists()
    }
    sensors.append(sensor)
  }

  public func connect() async {
    do {
      try await client.connect()
      client.addCloseListener(named: "AsyncClient") { [self] _ in
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

  func addSensorListeners(qos: MQTTQoS = .exactlyOnce) async throws {
    for sensor in sensors {
      try await client.subscribeToSensor(sensor, qos: qos)
      let listener = client.createPublishListener()
      for await result in listener {
        switch result {
        case let .success(value):
          var buffer = value.payload
          let topic = value.topicName
          logger.debug("Received new value for topic: \(topic)")

          if topic.contains("temperature") {
            // Decode and update the temperature value
            guard let temperature = Temperature(buffer: &buffer) else {
              logger.debug("Failed to decode temperature from buffer: \(buffer)")
              throw DecodingError()
            }
            try sensors.update(topic: topic, keyPath: \.temperature, with: temperature)

          } else if topic.contains("humidity") {
            // Decode and update the temperature value
            guard let humidity = RelativeHumidity(buffer: &buffer) else {
              logger.debug("Failed to decode humidity from buffer: \(buffer)")
              throw DecodingError()
            }
            try sensors.update(topic: topic, keyPath: \.humidity, with: humidity)

          } else {
            let message = """
            Unexpected value for topic: \(topic)
            Expected to contain either 'temperature' or 'humidity'
            """
            logger.debug("\(message)")
          }

          // TODO: Publish dew-point & enthalpy if needed.

        case let .failure(error):
          logger.trace("Error:\n\(error)")
          throw error
        }
      }
    }
  }

  // Need to save the recieved values somewhere.
  // TODO: Remove.
  func addPublishListener<T>(
    topic: String,
    decoding _: T.Type
  ) async throws where T: BufferInitalizable {
    _ = try await client.subscribe(to: [.init(topicFilter: topic, qos: .atLeastOnce)])
    Task {
      let listener = self.client.createPublishListener()
      for await result in listener {
        switch result {
        case let .success(packet):
          var buffer = packet.payload
          guard let value = T(buffer: &buffer) else {
            logger.debug("Could not decode buffer: \(buffer)")
            return
          }
          logger.debug("Recieved value: \(value)")
        case let .failure(error):
          logger.trace("Error:\n\(error)")
        }
      }
    }
  }

  private func publish(string: String, to topic: String) async throws {
    try await client.publish(
      to: topic,
      payload: ByteBufferAllocator().buffer(string: string),
      qos: .atLeastOnce
    )
  }

  private func publish(double: Double, to topic: String) async throws {
    let rounded = round(double * 100) / 100
    try await publish(string: "\(rounded)", to: topic)
  }

  func publishDewPoint(_ request: Client.SensorPublishRequest) async throws {
    // fix
    guard let (dewPoint, topic) = request.dewPointData(topics: .init(), units: nil) else { return }
    try await publish(double: dewPoint.rawValue, to: topic)
    logger.debug("Published dewpoint: \(dewPoint.rawValue), to: \(topic)")
  }

  func publishEnthalpy(_ request: Client.SensorPublishRequest) async throws {
    // fix
    guard let (enthalpy, topic) = request.enthalpyData(altitude: .seaLevel, topics: .init(), units: nil) else { return }
    try await publish(double: enthalpy.rawValue, to: topic)
    logger.debug("Publihsed enthalpy: \(enthalpy.rawValue), to: \(topic)")
  }

  public func publishSensor(_ request: Client.SensorPublishRequest) async throws {
    try await publishDewPoint(request)
    try await publishEnthalpy(request)
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

extension TemperatureAndHumiditySensor.Topics {
  func contains(_ topic: String) -> Bool {
    temperature == topic || humidity == topic
  }
}

extension Array where Element == TemperatureAndHumiditySensor {

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

}
