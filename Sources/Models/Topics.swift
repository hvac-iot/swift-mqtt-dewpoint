public struct Topics {
  
  public var sensors: Sensors
  public var setPoints: SetPoints
  public var states: States
  public var relays: Relays
  
  public init(
    sensors: Sensors = .init(),
    setPoints: SetPoints = .init(),
    states: States = .init(),
    relays: Relays = .init()
  ) {
    self.sensors = sensors
    self.setPoints = setPoints
    self.states = states
    self.relays = relays
  }
  
  public struct Sensors {
    public var temperature: String
    public var humidity: String
    public var dewPoint: String
    
    public init(
      temperature: String = "sensors/temperature",
      humidity: String = "sensors/humidity",
      dewPoint: String = "sensors/dew_point"
    ) {
      self.temperature = temperature
      self.humidity = humidity
      self.dewPoint = dewPoint
    }
  }
  
  public struct SetPoints {
    public var humidify: String
    public var dehumidify: Dehumidify
    
    public init(
      humidify: String = "set_points/humidify",
      dehumidify: Dehumidify = .init()
    ) {
      self.humidify = humidify
      self.dehumidify = dehumidify
    }
    
    public struct Dehumidify {
      public var lowDewPoint: String
      public var highDewPoint: String
      public var lowRelativeHumidity: String
      public var highRelativeHumidity: String
      
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
  
  public struct States {
    public var mode: String
    
    public init(mode: String = "states/mode") {
      self.mode = mode
    }
  }
  
  public struct Relays {
    public var dehumidification1: String
    public var dehumidification2: String
    public var humidification: String
    
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
