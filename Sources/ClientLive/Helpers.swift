import CoreUnitTypes
import Logging
import Models
import MQTTNIO
import NIO
import Psychrometrics

/// Represents a type that can be initialized by a ``ByteBuffer``.
protocol BufferInitalizable {
  init?(buffer: inout ByteBuffer)
}

extension Temperature: BufferInitalizable {
  
  init?(buffer: inout ByteBuffer) {
    guard let string = buffer.readString(length: buffer.readableBytes, encoding: .utf8),
            let value = Double(string)
    else {
      return nil
    }
    self.init(value, units: .celsius)
  }
}

extension RelativeHumidity: BufferInitalizable {
  
  init?(buffer: inout ByteBuffer) {
    guard let string = buffer.readString(length: buffer.readableBytes, encoding: .utf8),
          let value = Double(string)
    else {
      return nil
    }
    self.init(value)
  }
}

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

fileprivate struct TemperatureAndHumiditySensorKeyPathEnvelope {
  
  let humidityTopic: KeyPath<Topics.Sensors, String>
  let temperatureTopic: KeyPath<Topics.Sensors, String>
  let temperatureState: WritableKeyPath<State.Sensors, Temperature?>
  let humidityState: WritableKeyPath<State.Sensors, RelativeHumidity?>
  
  func addListener(to client: MQTTNIO.MQTTClient, topics: Topics, state: State) {
    
    let temperatureTopic = topics.sensors[keyPath: temperatureTopic]
    client.logger.trace("Adding listener for topic: \(temperatureTopic)")
    client.addPublishListener(named: temperatureTopic) { result in
      result.logIfFailure(client: client, topic: temperatureTopic)
        .parse(as: Temperature.self)
        .map { temperature in
          state.sensors[keyPath: temperatureState] = temperature
        }
    }
    
    let humidityTopic = topics.sensors[keyPath: humidityTopic]
    client.logger.trace("Adding listener for topic: \(humidityTopic)")
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

extension Client.SensorPublishRequest {
  
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

extension MQTTNIO.MQTTClient {
  
  func publishDewPoint(
    request: Client.SensorPublishRequest,
    state: State,
    topics: Topics
  ) -> EventLoopFuture<(MQTTNIO.MQTTClient, Client.SensorPublishRequest, State, Topics)> {
    guard let (dewPoint, topic) = request.dewPointData(topics: topics, units: state.units)
    else {
      logger.trace("No dew point for sensor.")
      return eventLoopGroup.next().makeSucceededFuture((self, request, state, topics))
    }
    logger.debug("Publishing dew-point: \(dewPoint), to: \(topic)")
    return publish(
      to: topic,
      payload: ByteBufferAllocator().buffer(string: "\(dewPoint.rawValue)"),
      qos: .atLeastOnce
    )
    .map { (self, request, state, topics) }
  }
}

extension EventLoopFuture where Value == (Client.SensorPublishRequest, State) {
  func setHasProcessed() -> EventLoopFuture<Void> {
    map { request, state in
      request.setHasProcessed(state: state)
    }
  }
}

extension EventLoopFuture where Value == (MQTTNIO.MQTTClient, Client.SensorPublishRequest, State, Topics) {
  func publishEnthalpy() -> EventLoopFuture<(Client.SensorPublishRequest, State)> {
    flatMap { client, request, state, topics in
      guard let (enthalpy, topic) = request.enthalpyData(altitude: state.altitude, topics: topics, units: state.units)
      else {
        client.logger.trace("No enthalpy for sensor.")
        return client.eventLoopGroup.next().makeSucceededFuture((request, state))
      }
      client.logger.debug("Publishing enthalpy: \(enthalpy), to: \(topic)")
      return client.publish(
        to: topic,
        payload: ByteBufferAllocator().buffer(string: "\(enthalpy.rawValue)"),
        qos: .atLeastOnce
      )
        .map { (request, state) }
    }
  }
}
