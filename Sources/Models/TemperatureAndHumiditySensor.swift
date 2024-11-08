import Psychrometrics

/// Represents a temperature and humidity sensor that can be used to derive
/// the dew-point temperature and enthalpy values.
///
public struct TemperatureAndHumiditySensor: Equatable, Hashable, Identifiable {

  /// The identifier of the sensor, same as the location.
  public var id: Location { location }

  /// The altitude of the sensor.
  public let altitude: Length

  /// The current humidity value of the sensor.
  @TrackedChanges
  public var humidity: RelativeHumidity?

  /// The location identifier of the sensor
  public let location: Location

  /// The current temperature value of the sensor.
  @TrackedChanges
  public var temperature: Temperature?

  /// The topics to listen for updated sensor values.
  public let topics: Topics

  /// The psychrometric units of the sensor.
  public let units: PsychrometricEnvironment.Units

  /// Create a new temperature and humidity sensor.
  ///
  /// - Parameters:
  ///   - location: The location of the sensor.
  ///   - altitude: The altitude of the sensor.
  ///   - temperature: The current temperature value of the sensor.
  ///   - humidity: The current relative humidity value of the sensor.
  ///   - needsProcessed: If the sensor needs to be processed.
  ///   - units: The unit of measure for the sensor.
  public init(
    location: Location,
    altitude: Length = .feet(800.0),
    temperature: Temperature? = nil,
    humidity: RelativeHumidity? = nil,
    needsProcessed: Bool = false,
    units: PsychrometricEnvironment.Units = .imperial,
    topics: Topics? = nil
  ) {
    self.altitude = altitude
    self.location = location
    self._temperature = TrackedChanges(wrappedValue: temperature, needsProcessed: needsProcessed)
    self._humidity = TrackedChanges(wrappedValue: humidity, needsProcessed: needsProcessed)
    self.units = units
    self.topics = topics ?? .init(location: location)
  }

  /// The calculated dew-point temperature of the sensor.
  public var dewPoint: DewPoint? {
    guard let temperature = temperature,
          let humidity = humidity,
          !temperature.rawValue.isNaN,
          !humidity.rawValue.isNaN
    else { return nil }
    return .init(dryBulb: temperature, humidity: humidity, units: units)
  }

  /// The calculated enthalpy of the sensor.
  public var enthalpy: EnthalpyOf<MoistAir>? {
    guard let temperature = temperature,
          let humidity = humidity,
          !temperature.rawValue.isNaN,
          !humidity.rawValue.isNaN
    else { return nil }
    return .init(dryBulb: temperature, humidity: humidity, altitude: altitude, units: units)
  }

  /// Check whether any of the sensor values have changed and need processed.
  ///
  /// - Note: Setting a value will set to both the temperature and humidity properties.
  public var needsProcessed: Bool {
    get { $temperature.needsProcessed || $humidity.needsProcessed }
    set {
      $temperature.needsProcessed = newValue
      $humidity.needsProcessed = newValue
    }
  }

  /// Represents the different locations of a temperature and humidity sensor, which can
  /// be used to derive the topic to both listen and publish new values to.
  public enum Location: String, CaseIterable, Equatable, Hashable {
    case mixedAir = "mixed_air"
    case postCoil = "post_coil"
    case `return`
    case supply
  }

  /// Represents the MQTT topics to listen for updated sensor values on.
  public struct Topics: Equatable, Hashable {

    /// The dew-point temperature topic for the sensor.
    public let dewPoint: String

    /// The enthalpy topic for the sensor.
    public let enthalpy: String

    /// The humidity topic of the sensor.
    public let humidity: String

    /// The temperature topic of the sensor.
    public let temperature: String

    public init(
      dewPoint: String,
      enthalpy: String,
      humidity: String,
      temperature: String
    ) {
      self.dewPoint = dewPoint
      self.enthalpy = enthalpy
      self.humidity = humidity
      self.temperature = temperature
    }

    public init(topicPrefix: String? = "frankensystem", location: TemperatureAndHumiditySensor.Location) {
      var prefix = topicPrefix ?? ""
      if prefix.reversed().starts(with: "/") {
        prefix = "\(prefix.dropLast())"
      }
      self.init(
        dewPoint: "\(prefix)/sensors/\(location.rawValue)_dew_point/state",
        enthalpy: "\(prefix)/sensors/\(location.rawValue)_enthalpy/state",
        humidity: "\(prefix)/sensors/\(location.rawValue)_humidity/state",
        temperature: "\(prefix)/sensors/\(location.rawValue)_temperature/state"
      )
    }
  }
}
