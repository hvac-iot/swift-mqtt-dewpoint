import Models

// TODO: Fix other live topics
public extension Topics {

  static let live = Self(
    commands: .init(),
    sensors: .init(
      mixedAirSensor: .live(location: .mixedAir),
      postCoilSensor: .live(location: .postCoil),
      returnAirSensor: .live(location: .return),
      supplyAirSensor: .live(location: .supply)
    ),
    setPoints: .init(),
    states: .init()
  )
}

private extension Topics.Sensors {
  enum Location: CustomStringConvertible {
    case mixedAir
    case postCoil
    case `return`
    case supply

    var description: String {
      switch self {
      case .mixedAir:
        return "mixed_air"
      case .postCoil:
        return "post_coil"
      case .return:
        return "return"
      case .supply:
        return "supply"
      }
    }
  }
}

private extension Topics.Sensors.TemperatureAndHumiditySensor {
  static func live(
    prefix: String = "frankensystem",
    location: Topics.Sensors.Location
  ) -> Self {
    .init(
      temperature: "\(prefix)/sensor/\(location.description)_temperature/state",
      humidity: "\(prefix)/sensor/\(location.description)_humidity/state",
      dewPoint: "\(prefix)/sensor/\(location.description)_dew_point/state",
      enthalpy: "\(prefix)/sensor/\(location.description)_enthalpy/state"
    )
  }
}
