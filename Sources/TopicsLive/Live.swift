import Models

// TODO: Fix other live topics
extension Topics {
  
  public static let live = Self.init(
    commands: .init(),
    sensors: .init(
      mixedAirSensor: .live(location: .mixedAir),
      postCoilSensor: .live(location: .postCoil),
      returnAirSensor: .live(location: .return),
      supplyAirSensor: .live(location: .supply)),
    setPoints: .init(),
    states: .init()
  )
}

extension Topics.Sensors {
  fileprivate enum Location: CustomStringConvertible {
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

extension Topics.Sensors.TemperatureAndHumiditySensor {
  fileprivate static func live(
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
