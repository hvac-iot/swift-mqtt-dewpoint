import PsychrometricClient

// TODO: Remove

/// Represents the different modes that the controller can be in.
public enum Mode: Equatable {

  /// Allows controller to run in humidify or dehumidify mode.
  case auto

  /// Only handle humidify mode.
  case humidifyOnly(HumidifyMode)

  /// Only handle dehumidify mode.
  case dehumidifyOnly(DehumidifyMode)

  /// Don't control humidify or dehumidify modes.
  case off

  /// Represents the control modes for the humidify control state.
  public enum HumidifyMode: Equatable {

    /// Control humidifying based off dew-point.
    case dewPoint(DewPoint)

    /// Control humidifying based off relative humidity.
    case relativeHumidity(RelativeHumidity)
  }

  /// Represents the control modes for the dehumidify control state.
  public enum DehumidifyMode: Equatable {

    /// Control dehumidifying based off dew-point.
    case dewPoint(high: DewPoint, low: DewPoint)

    /// Control humidifying based off relative humidity.
    case relativeHumidity(high: RelativeHumidity, low: RelativeHumidity)
  }
}
