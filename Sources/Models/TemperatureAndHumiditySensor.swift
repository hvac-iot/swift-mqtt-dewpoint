import Dependencies
import PsychrometricClient

/// Represents a temperature and humidity sensor that can be used to derive
/// the dew-point temperature and enthalpy values.
///
/// > Note: Temperature values are received in `celsius`.
public struct TemperatureAndHumiditySensor: Identifiable, Sendable {

  @Dependency(\.psychrometricClient) private var psychrometrics

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
  public var temperature: DryBulb?

  /// The topics to listen for updated sensor values.
  public let topics: Topics

  /// Create a new temperature and humidity sensor.
  ///
  /// - Parameters:
  ///   - location: The location of the sensor.
  ///   - altitude: The altitude of the sensor.
  ///   - temperature: The current temperature value of the sensor.
  ///   - humidity: The current relative humidity value of the sensor.
  ///   - needsProcessed: If the sensor needs to be processed.
  public init(
    location: Location,
    altitude: Length = .feet(800.0),
    temperature: DryBulb? = nil,
    humidity: RelativeHumidity? = nil,
    needsProcessed: Bool = false,
    topics: Topics? = nil
  ) {
    self.altitude = altitude
    self.location = location
    self._temperature = TrackedChanges(wrappedValue: temperature, needsProcessed: needsProcessed)
    self._humidity = TrackedChanges(wrappedValue: humidity, needsProcessed: needsProcessed)
    self.topics = topics ?? .init(location: location)
  }

  /// The calculated dew-point temperature of the sensor.
  public var dewPoint: DewPoint? {
    get async {
      guard let temperature = temperature,
            let humidity = humidity,
            !temperature.value.isNaN,
            !humidity.value.isNaN
      else { return nil }
      return try? await psychrometrics.dewPoint(.dryBulb(temperature, relativeHumidity: humidity))
    }
  }

  /// The calculated enthalpy of the sensor.
  public var enthalpy: EnthalpyOf<MoistAir>? {
    get async {
      guard let temperature = temperature,
            let humidity = humidity,
            !temperature.value.isNaN,
            !humidity.value.isNaN
      else { return nil }
      return try? await psychrometrics.enthalpy.moistAir(
        .dryBulb(temperature, relativeHumidity: humidity, altitude: altitude)
      )
    }
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
  public enum Location: String, CaseIterable, Equatable, Hashable, Sendable {
    case mixedAir = "mixed_air"
    case postCoil = "post_coil"
    case `return`
    case supply
  }

  /// Represents the MQTT topics to listen for updated sensor values on.
  public struct Topics: Equatable, Hashable, Sendable {

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
        dewPoint: "\(prefix)/sensor/\(location.rawValue)_dew_point/state",
        enthalpy: "\(prefix)/sensor/\(location.rawValue)_enthalpy/state",
        humidity: "\(prefix)/sensor/\(location.rawValue)_humidity/state",
        temperature: "\(prefix)/sensor/\(location.rawValue)_temperature/state"
      )
    }
  }
}
