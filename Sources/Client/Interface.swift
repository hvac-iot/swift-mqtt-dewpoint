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
  
  /// Retrieve the temperature from the MQTT Broker.
  public var fetchTemperature: (Sensor<Temperature>, PsychrometricEnvironment.Units?) -> EventLoopFuture<Temperature>
  
  /// Publish a change of state message for a relay.
  public var setRelay: (Relay, Relay.State) -> EventLoopFuture<Void>
  
  /// Disconnect and close the connection to the MQTT Broker.
  public var shutdown: () -> EventLoopFuture<Void>
  
  /// Publish the current dew point to the MQTT Broker
  public var publishDewPoint: (DewPoint, String) -> EventLoopFuture<Void>
  
  public init(
    fetchHumidity: @escaping (Sensor<RelativeHumidity>) -> EventLoopFuture<RelativeHumidity>,
    fetchTemperature: @escaping (Sensor<Temperature>, PsychrometricEnvironment.Units?) -> EventLoopFuture<Temperature>,
    setRelay: @escaping (Relay, Relay.State) -> EventLoopFuture<Void>,
    shutdown: @escaping () -> EventLoopFuture<Void>,
    publishDewPoint: @escaping (DewPoint, String) -> EventLoopFuture<Void>
  ) {
    self.fetchHumidity = fetchHumidity
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
  public func `set`(relay: Relay, to state: Relay.State) -> EventLoopFuture<Void> {
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
