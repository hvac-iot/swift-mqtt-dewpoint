import Foundation
@_exported import Client
import CoreUnitTypes
import Models
import MQTTNIO
import NIO
import Psychrometrics

extension Client.MQTTClient {
  
  /// Creates the live implementation of our ``Client.MQTTClient`` for the application.
  ///
  /// - Parameters:
  ///   - client: The ``MQTTNIO.MQTTClient`` used to send and recieve messages from the MQTT Broker.
  public static func live(client: MQTTNIO.MQTTClient, topics: Topics) -> Self {
    .init(
      fetchHumidity: { sensor in
        client.fetch(sensor: sensor)
          .debug(logger: client.logger)
      },
      fetchSetPoint: { setPointKeyPath in
        client.fetch(client.mqttSubscription(topic: topics.setPoints[keyPath: setPointKeyPath]))
          .debug(logger: client.logger)
      },
      fetchTemperature: { sensor, units in
        client.fetch(sensor: sensor)
          .debug(logger: client.logger)
          .convertIfNeeded(to: units)
          .debug(logger: client.logger)
      },
      setRelay: { relayKeyPath, state in
        client.set(relay: topics.commands.relays[keyPath: relayKeyPath], to: state)
      },
      shutdown: {
        client.disconnect()
          .map { try? client.syncShutdownGracefully() }
      },
      publishDewPoint: { dewPoint, topic in
        client.publish(
          to: topic,
          payload: ByteBufferAllocator().buffer(string: "\(dewPoint.rawValue)"),
          qos: .atLeastOnce
        )
      }
    )
  }
}

extension Client2 {
  
  // The state passed in here needs to be a class or we get escaping errors in the `addListeners` method.
  public static func live(
    client: MQTTNIO.MQTTClient,
    state: State,
    topics: Topics
  ) -> Self {
    .init(
      // TODO: Fix adding listeners in a more generic way.
      addListeners: {
//        state.addSensorListeners(to: client, topics: topics)
        client.addPublishListener(named: topics.sensors.returnAirSensor.temperature) { result in
          let topic = topics.sensors.returnAirSensor.temperature
          result.logIfFailure(client: client, topic: topic)
            .parse(as: Temperature.self)
            .map { temperature -> () in
              state.sensors.returnAirSensor.temperature = temperature
            }
        }
        client.addPublishListener(named: topics.sensors.returnAirSensor.humidity) { result in
          let topic = topics.sensors.returnAirSensor.humidity
          result.logIfFailure(client: client, topic: topic)
            .parse(as: RelativeHumidity.self)
            .map { humidity -> () in
              state.sensors.returnAirSensor.humidity = humidity
            }
        }
      },
      connect: {
        client.connect()
          .map { _ in }
      },
      publishSensor: { request in
        guard let (dewPoint, topic) = request.dewPointData(topics: topics, units: state.units)
        else {
          client.logger.debug("No dew point for sensor.")
          return client.eventLoopGroup.next().makeSucceededVoidFuture()
        }
        client.logger.debug("Publishing dew-point: \(dewPoint), to: \(topic)")
        return client.publish(
          to: topic,
          payload: ByteBufferAllocator().buffer(string: "\(dewPoint.rawValue)"),
          qos: .atLeastOnce
        )
        .flatMap {
          guard let (enthalpy, topic) = request.enthalpyData(altitude: state.altitude, topics: topics, units: state.units)
          else {
            client.logger.debug("No enthalpy for sensor.")
            return client.eventLoopGroup.next().makeSucceededVoidFuture()
          }
          client.logger.debug("Publishing enthalpy: \(enthalpy), to: \(topic)")
          return client.publish(
            to: topic,
            payload: ByteBufferAllocator().buffer(string: "\(enthalpy.rawValue)"),
            qos: .atLeastOnce
          )
        }
        .map {
          request.setHasProcessed(state: state)
        }
      },
      shutdown: {
        client.disconnect()
          .map { try? client.syncShutdownGracefully() }
      },
      subscribe: {
        // Sensor subscriptions
        client.subscribe(to: .sensors(topics: topics))
        .map { _ in }
      }
    )
  }
}

// MARK: - Client2 Helpers.
extension MQTTNIO.MQTTClient {
  
  func logFailure(topic: String, error: Error) {
    logger.error("\(topic): \(error)")
  }
}

extension Result where Success == MQTTPublishInfo {
  func logIfFailure(client: MQTTNIO.MQTTClient, topic: String) -> ByteBuffer? {
    switch self {
    case let .success(value):
      guard value.topicName == topic else { return nil }
      return value.payload
    case let .failure(error):
      client.logFailure(topic: topic, error: error)
      return nil
    }
  }
}

extension Optional where Wrapped == ByteBuffer {
  
  func parse<T>(as type: T.Type) -> T? where T: BufferInitalizable {
    switch self {
    case var .some(buffer):
      return T.init(buffer: &buffer)
    case .none:
      return nil
    }
  }
}

struct TemperatureAndHumiditySensorKeyPathEnvelope {
  
  let humidityTopic: KeyPath<Topics.Sensors, String>
  let temperatureTopic: KeyPath<Topics.Sensors, String>
  let temperatureState: WritableKeyPath<State.Sensors, Temperature?>
  let humidityState: WritableKeyPath<State.Sensors, RelativeHumidity?>
  
  func addListener(to client: MQTTNIO.MQTTClient, topics: Topics, state: State) {
    
    let temperatureTopic = topics.sensors[keyPath: temperatureTopic]
    client.addPublishListener(named: temperatureTopic) { result in
      result.logIfFailure(client: client, topic: temperatureTopic)
        .parse(as: Temperature.self)
        .map { temperature in
          state.sensors[keyPath: temperatureState] = temperature
        }
    }
    
    let humidityTopic = topics.sensors[keyPath: humidityTopic]
    client.addPublishListener(named: humidityTopic) { result in
      result.logIfFailure(client: client, topic: humidityTopic)
        .parse(as: RelativeHumidity.self)
        .map { humidity in
          state.sensors[keyPath: humidityState] = humidity
        }
    }
  }
}

extension Array where Element == TemperatureAndHumiditySensorKeyPathEnvelope {
  func addListeners(to client: MQTTNIO.MQTTClient, topics: Topics, state: State) {
    _ = self.map { envelope in
      envelope.addListener(to: client, topics: topics, state: state)
    }
  }
}

extension Array where Element == MQTTSubscribeInfo {
  static func sensors(topics: Topics) -> Self {
    [
      .init(topicFilter: topics.sensors.mixedAirSensor.temperature, qos: .atLeastOnce),
      .init(topicFilter: topics.sensors.mixedAirSensor.humidity, qos: .atLeastOnce),
      .init(topicFilter: topics.sensors.postCoilSensor.temperature, qos: .atLeastOnce),
      .init(topicFilter: topics.sensors.postCoilSensor.humidity, qos: .atLeastOnce),
      .init(topicFilter: topics.sensors.returnAirSensor.temperature, qos: .atLeastOnce),
      .init(topicFilter: topics.sensors.returnAirSensor.humidity, qos: .atLeastOnce),
      .init(topicFilter: topics.sensors.supplyAirSensor.temperature, qos: .atLeastOnce),
      .init(topicFilter: topics.sensors.supplyAirSensor.humidity, qos: .atLeastOnce),
    ]
  }
}

extension State {
  func addSensorListeners(to client: MQTTNIO.MQTTClient, topics: Topics) {
    let envelopes: [TemperatureAndHumiditySensorKeyPathEnvelope] = [
      .init(
        humidityTopic: \.mixedAirSensor.humidity,
        temperatureTopic: \.mixedAirSensor.temperature,
        temperatureState: \.mixedAirSensor.temperature,
        humidityState: \.mixedAirSensor.humidity
      ),
      .init(
        humidityTopic: \.postCoilSensor.humidity,
        temperatureTopic: \.postCoilSensor.temperature,
        temperatureState: \.postCoilSensor.temperature,
        humidityState: \.postCoilSensor.humidity
      ),
      .init(
        humidityTopic: \.returnAirSensor.humidity,
        temperatureTopic: \.returnAirSensor.temperature,
        temperatureState: \.returnAirSensor.temperature,
        humidityState: \.returnAirSensor.humidity
      ),
      .init(
        humidityTopic: \.supplyAirSensor.humidity,
        temperatureTopic: \.supplyAirSensor.temperature,
        temperatureState: \.supplyAirSensor.temperature,
        humidityState: \.supplyAirSensor.humidity
      ),
    ]
    envelopes.addListeners(to: client, topics: topics, state: self)
  }
}

extension Client2.SensorPublishRequest {
  
  func dewPointData(topics: Topics, units: PsychrometricEnvironment.Units?) -> (DewPoint, String)? {
    switch self {
    case let .mixed(sensor):
      guard let dp = sensor.dewPoint(units: units) else { return nil }
      return (dp, topics.sensors.mixedAirSensor.dewPoint)
    case let .postCoil(sensor):
      guard let dp = sensor.dewPoint(units: units) else { return nil }
      return (dp, topics.sensors.postCoilSensor.dewPoint)
    case let .return(sensor):
      guard let dp = sensor.dewPoint(units: units) else { return nil }
      return (dp, topics.sensors.returnAirSensor.dewPoint)
    case let .supply(sensor):
      guard let dp = sensor.dewPoint(units: units) else { return nil }
      return (dp, topics.sensors.supplyAirSensor.dewPoint)
    }
  }
  
  func enthalpyData(altitude: Length, topics: Topics, units: PsychrometricEnvironment.Units?) -> (EnthalpyOf<MoistAir>, String)? {
    switch self {
    case let .mixed(sensor):
      guard let enthalpy = sensor.enthalpy(altitude: altitude, units: units) else { return nil }
      return (enthalpy, topics.sensors.mixedAirSensor.enthalpy)
    case let .postCoil(sensor):
      guard let enthalpy = sensor.enthalpy(altitude: altitude, units: units) else { return nil }
      return (enthalpy, topics.sensors.postCoilSensor.enthalpy)
    case let .return(sensor):
      guard let enthalpy = sensor.enthalpy(altitude: altitude, units: units) else { return nil }
      return (enthalpy, topics.sensors.returnAirSensor.enthalpy)
    case let .supply(sensor):
      guard let enthalpy = sensor.enthalpy(altitude: altitude, units: units) else { return nil }
      return (enthalpy, topics.sensors.supplyAirSensor.enthalpy)
    }
  }
  
  func setHasProcessed(state: State) {
    switch self {
    case .mixed:
      state.sensors.mixedAirSensor.needsProcessed = false
    case .postCoil:
      state.sensors.postCoilSensor.needsProcessed = false
    case .return:
      state.sensors.returnAirSensor.needsProcessed = false
    case .supply:
      state.sensors.supplyAirSensor.needsProcessed = false
    }
  }
}
