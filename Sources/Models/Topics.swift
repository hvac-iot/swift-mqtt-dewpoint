
/// A container for all the different MQTT topics that are needed by the application.
public struct Topics: Codable, Equatable {

  /// The command topics the application can publish to.
  public var commands: Commands

  /// The sensor topics the application can read from / write to.
  public var sensors: Sensors

  /// The set point topics the application can read set point values from.
  public var setPoints: SetPoints

  /// The state topics the application can read state values from.
  public var states: States

  /// Create the topics required by the application.
  ///
  /// - Parameters:
  ///   - sensors: The sensor topics.
  ///   - setPoints: The set point topics
  ///   - states: The states topics
  ///   - relays: The relay topics
  public init(
    commands: Commands = .init(),
    sensors: Sensors = .init(),
    setPoints: SetPoints = .init(),
    states: States = .init()
  ) {
    self.commands = commands
    self.sensors = sensors
    self.setPoints = setPoints
    self.states = states
  }

  /// Represents the sensor topics.
  public struct Sensors: Codable, Equatable {

    public var mixedAirSensor: TemperatureAndHumiditySensor<State.Sensors.MixedAir>
    public var postCoilSensor: TemperatureAndHumiditySensor<State.Sensors.PostCoil>
    public var returnAirSensor: TemperatureAndHumiditySensor<State.Sensors.Return>
    public var supplyAirSensor: TemperatureAndHumiditySensor<State.Sensors.Supply>

    public init(
      mixedAirSensor: TemperatureAndHumiditySensor<State.Sensors.MixedAir> = .default(location: "mixed-air"),
      postCoilSensor: TemperatureAndHumiditySensor<State.Sensors.PostCoil> = .default(location: "post-coil"),
      returnAirSensor: TemperatureAndHumiditySensor<State.Sensors.Return> = .default(location: "return"),
      supplyAirSensor: TemperatureAndHumiditySensor<State.Sensors.Supply> = .default(location: "supply")
    ) {
      self.mixedAirSensor = mixedAirSensor
      self.postCoilSensor = postCoilSensor
      self.returnAirSensor = returnAirSensor
      self.supplyAirSensor = supplyAirSensor
    }

    public struct TemperatureAndHumiditySensor<Location>: Codable, Equatable {
      public var temperature: String
      public var humidity: String
      public var dewPoint: String
      public var enthalpy: String

      /// Create a new sensor topic container.
      ///
      /// - Parameters:
      ///   - temperature: The temperature sensor topic.
      ///   - humidity: The humidity sensor topic.
      ///   - dewPoint: The dew point sensor topic.
      public init(
        temperature: String,
        humidity: String,
        dewPoint: String,
        enthalpy: String
      ) {
        self.temperature = temperature
        self.humidity = humidity
        self.dewPoint = dewPoint
        self.enthalpy = enthalpy
      }
    }
  }

  /// A container for set point related topics used by the application.
  public struct SetPoints: Codable, Equatable {

    /// The topic for the humidify set point.
    public var humidify: Humidify

    /// The topics for dehumidification set points.
    public var dehumidify: Dehumidify

    /// Create a new set point topic container.
    ///
    /// - Parameters:
    ///   - humidify: The topic for humidification set points.
    ///   - dehumidify: The topics for dehumidification set points.
    public init(
      humidify: Humidify = .init(),
      dehumidify: Dehumidify = .init()
    ) {
      self.humidify = humidify
      self.dehumidify = dehumidify
    }

    /// A container for the humidification set point topics used by the application.
    public struct Humidify: Codable, Equatable {

      /// The topic for dew point control mode set point.
      public var dewPoint: String

      /// The topic for relative humidity control mode set point.
      public var relativeHumidity: String

      /// Create a new container for the humidification set point topics.
      ///
      /// - Parameters:
      ///   - dewPoint: The topic for dew point control mode set point.
      ///   - relativeHumidity: The topic for relative humidity control mode set point.
      public init(
        dewPoint: String = "set_points/humidify/dew_point",
        relativeHumidity: String = "set_points/humidify/relative_humidity"
      ) {
        self.dewPoint = dewPoint
        self.relativeHumidity = relativeHumidity
      }
    }

    /// A container for dehumidifcation set point topics.
    public struct Dehumidify: Codable, Equatable {

      /// A low setting for dew point control modes.
      public var lowDewPoint: String

      /// A high setting for dew point control modes.
      public var highDewPoint: String

      /// A low setting for relative humidity control modes.
      public var lowRelativeHumidity: String

      /// A high setting for relative humidity control modes.
      public var highRelativeHumidity: String

      /// Create a new container for dehumidification set point topics.
      ///
      /// - Parameters:
      ///   - lowDewPoint: A low setting for dew point control modes.
      ///   - highDewPoint: A high setting for dew point control modes.
      ///   - lowRelativeHumidity: A low setting for relative humidity control modes.
      ///   - highRelativeHumidity: A high setting for relative humidity control modes.
      public init(
        lowDewPoint: String = "set_points/dehumidify/low_dew_point",
        highDewPoint: String = "set_points/dehumidify/high_dew_point",
        lowRelativeHumidity: String = "set_points/dehumidify/low_relative_humidity",
        highRelativeHumidity: String = "set_points/dehumidify/high_relative_humidity"
      ) {
        self.lowDewPoint = lowDewPoint
        self.highDewPoint = highDewPoint
        self.lowRelativeHumidity = lowRelativeHumidity
        self.highRelativeHumidity = highRelativeHumidity
      }
    }
  }

  /// A container for control state topics used by the application.
  public struct States: Codable, Equatable {

    /// The topic for the control mode.
    public var mode: String

    /// The relay state topics.
    public var relays: Relays

    /// Create a new container for control state topics.
    ///
    /// - Parameters:
    ///   - mode: The topic for the control mode.
    public init(
      mode: String = "states/mode",
      relays: Relays = .init()
    ) {
      self.mode = mode
      self.relays = relays
    }

    /// A container for reading the current state of a relay.
    public struct Relays: Codable, Equatable {

      /// The dehumidification stage-1 relay topic.
      public var dehumdification1: String

      /// The dehumidification stage-2 relay topic.
      public var dehumidification2: String

      /// The humidification relay topic.
      public var humdification: String

      /// Create a new container for relay state topics.
      ///
      /// - Parameters:
      ///   - dehumidification1: The dehumidification stage-1 relay topic.
      ///   - dehumidification2: The dehumidification stage-2 relay topic.
      ///   - humidification: The humidification relay topic.
      public init(
        dehumidefication1: String = "states/relays/dehumidification_1",
        dehumidification2: String = "states/relays/dehumidification_2",
        humidification: String = "states/relays/humidification"
      ) {
        self.dehumdification1 = dehumidefication1
        self.dehumidification2 = dehumidification2
        self.humdification = humidification
      }
    }
  }

  /// A container for commands topics that the application can publish to.
  public struct Commands: Codable, Equatable {

    /// The relay command topics.
    public var relays: Relays

    /// Create a new command topics container.
    ///
    ///  - Parameters:
    ///   - relays: The relay command topics.
    public init(relays: Relays = .init()) {
      self.relays = relays
    }

    /// A container for relay command topics used by the application.
    public struct Relays: Codable, Equatable {

      /// The dehumidification stage-1 relay topic.
      public var dehumidification1: String

      /// The dehumidification stage-2 relay topic.
      public var dehumidification2: String

      /// The humidification relay topic.
      public var humidification: String

      /// Create a new container for commanding relays.
      ///
      /// - Parameters:
      ///   - dehumidification1: The dehumidification stage-1 relay topic.
      ///   - dehumidification2: The dehumidification stage-2 relay topic.
      ///   - humidification: The humidification relay topic.
      public init(
        dehumidification1: String = "relays/dehumidification_1",
        dehumidification2: String = "relays/dehumidification_2",
        humidification: String = "relays/humidification"
      ) {
        self.dehumidification1 = dehumidification1
        self.dehumidification2 = dehumidification2
        self.humidification = humidification
      }
    }
  }
}

// MARK: Helpers
extension Topics.Sensors.TemperatureAndHumiditySensor {
  public static func `default`(location: String) -> Self {
    .init(
      temperature: "sensors/\(location)/temperature",
      humidity: "sensors/\(location)/humidity",
      dewPoint: "sensors/\(location)/dew-point",
      enthalpy: "sensors/\(location)/enthalpy"
    )
  }
}
