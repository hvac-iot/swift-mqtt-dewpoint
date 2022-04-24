import CoreUnitTypes
import Logging
import Foundation
import Models
import NIO
import Psychrometrics

public struct Client {
  
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

public struct AsyncClient {
}
