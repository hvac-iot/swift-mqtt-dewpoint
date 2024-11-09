import Foundation
import PsychrometricClient

// TODO: Remove
// TODO: Make this a struct, then create a Store class that holds the state??
public final class State {

  public var altitude: Length
  public var sensors: Sensors
  public var units: PsychrometricUnits

  public init(
    altitude: Length = .seaLevel,
    sensors: Sensors = .init(),
    units: PsychrometricUnits = .imperial
  ) {
    self.altitude = altitude
    self.sensors = sensors
    self.units = units
  }

  public struct Sensors: Equatable {

    public var mixedAirSensor: TemperatureHumiditySensor<MixedAir>
    public var postCoilSensor: TemperatureHumiditySensor<PostCoil>
    public var returnAirSensor: TemperatureHumiditySensor<Return>
    public var supplyAirSensor: TemperatureHumiditySensor<Supply>

    public init(
      mixedAirSensor: TemperatureHumiditySensor<MixedAir> = .init(),
      postCoilSensor: TemperatureHumiditySensor<PostCoil> = .init(),
      returnAirSensor: TemperatureHumiditySensor<Return> = .init(),
      supplyAirSensor: TemperatureHumiditySensor<Supply> = .init()
    ) {
      self.mixedAirSensor = mixedAirSensor
      self.postCoilSensor = postCoilSensor
      self.returnAirSensor = returnAirSensor
      self.supplyAirSensor = supplyAirSensor
    }

    public var needsProcessed: Bool {
      mixedAirSensor.needsProcessed
        || postCoilSensor.needsProcessed
        || returnAirSensor.needsProcessed
        || supplyAirSensor.needsProcessed
    }
  }
}

public extension State.Sensors {

  struct TemperatureHumiditySensor<Location>: Equatable {

    @TrackedChanges
    public var temperature: DryBulb?

    @TrackedChanges
    public var humidity: RelativeHumidity?

    public var needsProcessed: Bool {
      get { $temperature.needsProcessed || $humidity.needsProcessed }
      set {
        $temperature.needsProcessed = newValue
        $humidity.needsProcessed = newValue
      }
    }

    // WARN: Fix me.
    public func dewPoint(units _: PsychrometricUnits? = nil) -> DewPoint? {
      guard let temperature = temperature,
            let humidity = humidity
      else { return nil }
      return nil
      // return .init(dryBulb: temperature, humidity: humidity, units: units)
    }

    // WARN: Fix me.
    public func enthalpy(altitude _: Length, units _: PsychrometricUnits? = nil) -> EnthalpyOf<MoistAir>? {
      guard let temperature = temperature,
            let humidity = humidity
      else { return nil }
      return nil
      // return .init(dryBulb: temperature, humidity: humidity, altitude: altitude, units: units)
    }

    public init(
      temperature: DryBulb? = nil,
      humidity: RelativeHumidity? = nil,
      needsProcessed: Bool = false
    ) {
      self._temperature = .init(wrappedValue: temperature, needsProcessed: needsProcessed)
      self._humidity = .init(wrappedValue: humidity, needsProcessed: needsProcessed)
    }
  }

  // MARK: - Temperature / Humidity Sensor Location Namespaces

  enum MixedAir {}
  enum PostCoil {}
  enum Return {}
  enum Supply {}
}
