import CoreUnitTypes
import Logging
import Foundation
import Models
import NIO
import Psychrometrics

public struct Client {
  
  public var fetchHumidity: (HumiditySensor) -> EventLoopFuture<RelativeHumidity>
  public var fetchTemperature: (TemperatureSensor, PsychrometricEnvironment.Units?) -> EventLoopFuture<Temperature>
  public var toggleRelay: (Relay) -> EventLoopFuture<Void>
  public var turnOnRelay: (Relay) -> EventLoopFuture<Void>
  public var turnOffRelay: (Relay) -> EventLoopFuture<Void>
  public var shutdown: () -> EventLoopFuture<Void>
  
  public init(
    fetchHumidity: @escaping (HumiditySensor) -> EventLoopFuture<RelativeHumidity>,
    fetchTemperature: @escaping (TemperatureSensor, PsychrometricEnvironment.Units?) -> EventLoopFuture<Temperature>,
    toggleRelay: @escaping (Relay) -> EventLoopFuture<Void>,
    turnOnRelay: @escaping (Relay) -> EventLoopFuture<Void>,
    turnOffRelay: @escaping (Relay) -> EventLoopFuture<Void>,
    shutdown: @escaping () -> EventLoopFuture<Void>
  ) {
    self.fetchHumidity = fetchHumidity
    self.fetchTemperature = fetchTemperature
    self.toggleRelay = toggleRelay
    self.turnOnRelay = turnOnRelay
    self.turnOffRelay = turnOffRelay
    self.shutdown = shutdown
  }
  
  public func fetchDewPoint(
    temperature: TemperatureSensor,
    humidity: HumiditySensor,
    units: PsychrometricEnvironment.Units? = nil,
    logger: Logger? = nil
  ) -> EventLoopFuture<DewPoint> {
    fetchTemperature(temperature, units)
      .and(fetchHumidity(humidity))
      .map { temp, humidity in
        logger?.debug("Creating dew-point for temperature: \(temp) with humidity: \(humidity)")
        return DewPoint.init(dryBulb: temp, humidity: humidity, units: units)
      }
  }
}
