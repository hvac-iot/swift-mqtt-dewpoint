import CoreUnitTypes
import Logging
import Foundation
import Models
import NIO
import Psychrometrics

/// Represents the applications interactions with the MQTT Broker.
///
/// This is an abstraction around the ``MQTTNIO.MQTTClient``.
public struct MQTTClient {
    
  /// Retrieve the humidity from the MQTT Broker.
  public var fetchHumidity: (Sensor<RelativeHumidity>) -> EventLoopFuture<RelativeHumidity>
  
  /// Retrieve a set point from the MQTT Broker.
  public var fetchSetPoint: (KeyPath<Topics.SetPoints, String>) -> EventLoopFuture<Double>
  
  /// Retrieve the temperature from the MQTT Broker.
  public var fetchTemperature: (Sensor<Temperature>, PsychrometricEnvironment.Units?) -> EventLoopFuture<Temperature>
  
  /// Publish a change of state message for a relay.
  public var setRelay: (KeyPath<Topics.Commands.Relays, String>, Relay.State) -> EventLoopFuture<Void>
  
  /// Disconnect and close the connection to the MQTT Broker.
  public var shutdown: () -> EventLoopFuture<Void>
  
  /// Publish the current dew point to the MQTT Broker
  public var publishDewPoint: (DewPoint, String) -> EventLoopFuture<Void>
  
  public init(
    fetchHumidity: @escaping (Sensor<RelativeHumidity>) -> EventLoopFuture<RelativeHumidity>,
    fetchSetPoint: @escaping (KeyPath<Topics.SetPoints, String>) -> EventLoopFuture<Double>,
    fetchTemperature: @escaping (Sensor<Temperature>, PsychrometricEnvironment.Units?) -> EventLoopFuture<Temperature>,
    setRelay: @escaping (KeyPath<Topics.Commands.Relays, String>, Relay.State) -> EventLoopFuture<Void>,
    shutdown: @escaping () -> EventLoopFuture<Void>,
    publishDewPoint: @escaping (DewPoint, String) -> EventLoopFuture<Void>
  ) {
    self.fetchHumidity = fetchHumidity
    self.fetchSetPoint = fetchSetPoint
    self.fetchTemperature = fetchTemperature
    self.setRelay = setRelay
    self.shutdown = shutdown
    self.publishDewPoint = publishDewPoint
  }
  
  /// Fetches the current temperature and humidity and calculates the current dew point.
  ///
  /// - Parameters:
  ///   - temperature: The temperature sensor to fetch the temperature from.
  ///   - humidity: The humidity sensor to fetch the humidity from.
  ///   - units: Optional units for the dew point.
  public func currentDewPoint(
    temperature: Sensor<Temperature>,
    humidity: Sensor<RelativeHumidity>,
    units: PsychrometricEnvironment.Units? = nil
  ) -> EventLoopFuture<DewPoint> {
    fetchTemperature(temperature, units)
      .and(fetchHumidity(humidity))
      .convertToDewPoint(units: units)
  }
  
  /// Convenience to send a change of state message to a relay.
  ///
  /// - Parameters:
  ///   - relay: The relay to send the message to.
  ///   - state: The state to change the relay to.
  public func `set`(relay: KeyPath<Topics.Commands.Relays, String>, to state: Relay.State) -> EventLoopFuture<Void> {
    setRelay(relay, state)
  }
  
  /// Convenience to publish the current dew point back to the MQTT Broker.
  ///
  /// This is synactic sugar around ``MQTTClient.publishDewPoint``.
  ///
  /// - Parameters:
  ///   - dewPoint: The dew point value to publish.
  ///   - topic: The dew point topic to publish to.
  public func publish(dewPoint: DewPoint, to topic: String) -> EventLoopFuture<Void> {
    publishDewPoint(dewPoint, topic)
  }
}

extension EventLoopFuture where Value == (Temperature, RelativeHumidity) {
  
  fileprivate func convertToDewPoint(units: PsychrometricEnvironment.Units?) -> EventLoopFuture<DewPoint> {
    map { .init(dryBulb: $0, humidity: $1, units: units) }
  }
}

public struct Client2 {
  
  /// Add the publish listeners to the MQTT Broker, to be notified of published changes.
  public var addListeners: () -> Void
  
  /// Connect to the MQTT Broker.
  public var connect: () -> EventLoopFuture<Void>
  
  public var publishSensor: (SensorPublishRequest) -> EventLoopFuture<Void>
  
  /// Subscribe to appropriate topics / events.
  public var subscribe: () -> EventLoopFuture<Void>
  
  /// Disconnect and close the connection to the MQTT Broker.
  public var shutdown: () -> EventLoopFuture<Void>
  
  public init(
    addListeners: @escaping () -> Void,
    connect: @escaping () -> EventLoopFuture<Void>,
    publishSensor: @escaping (SensorPublishRequest) -> EventLoopFuture<Void>,
    shutdown: @escaping () -> EventLoopFuture<Void>,
    subscribe: @escaping () -> EventLoopFuture<Void>
  ) {
    self.addListeners = addListeners
    self.connect = connect
    self.publishSensor = publishSensor
    self.shutdown = shutdown
    self.subscribe = subscribe
  }
  
  public enum SensorPublishRequest {
    case mixed(State.Sensors.TemperatureHumiditySensor<State.Sensors.Mixed>)
    case postCoil(State.Sensors.TemperatureHumiditySensor<State.Sensors.PostCoil>)
    case `return`(State.Sensors.TemperatureHumiditySensor<State.Sensors.Return>)
    case supply(State.Sensors.TemperatureHumiditySensor<State.Sensors.Supply>)
  }
}
