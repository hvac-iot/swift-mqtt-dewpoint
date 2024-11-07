import Psychrometrics

public struct TemperatureAndHumiditySensor: Equatable, Identifiable {
    /// The identifier of the sensor, same as the location.
    public var id: Location { location }

    public let altitude: Length

    /// The location identifier of the sensor
    public let location: Location

    /// The current temperature value of the sensor.
    @TrackedChanges
    public var temperature: Temperature?

    /// The current humidity value of the sensor.
    @TrackedChanges
    public var humidity: RelativeHumidity?

    /// The psychrometric units of the sensor.
    public let units: PsychrometricEnvironment.Units

    public init(
        location: Location,
        altitude: Length = .feet(800.0),
        temperature: Temperature? = nil,
        humidity: RelativeHumidity? = nil,
        needsProcessed: Bool = false,
        units: PsychrometricEnvironment.Units = .imperial
    ) {
        self.altitude = altitude
        self.location = location
        self._temperature = .init(wrappedValue: temperature, needsProcessed: needsProcessed)
        self._humidity = .init(wrappedValue: humidity, needsProcessed: needsProcessed)
        self.units = units
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

    /// Check whether any of the sensor values have changed and need processed.
    public var needsProcessed: Bool {
        get { $temperature.needsProcessed || $humidity.needsProcessed }
        set {
            $temperature.needsProcessed = newValue
            $humidity.needsProcessed = newValue
        }
    }

    /// Represents the different locations of a temperature and humidity sensor, which can
    /// be used to derive the topic to both listen and publish new values to.
    public enum Location: String, Equatable, Hashable {
        case mixedAir = "mixed-air"
        case postCoil = "post-coil"
        case `return`
        case supply
    }
}
