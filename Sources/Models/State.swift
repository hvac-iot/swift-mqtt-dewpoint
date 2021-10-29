import Foundation
import CoreUnitTypes

public struct State: Equatable {
  
  public var sensors: Sensors
  
  public init(sensors: Sensors = .init()) {
    self.sensors = sensors
  }
  
  public struct Sensors: Equatable {
    
    public var mixedSensor: TemperatureHumiditySensor<Mixed>
    public var postCoilSensor: TemperatureHumiditySensor<PostCoil>
    public var returnSensor: TemperatureHumiditySensor<Return>
    public var supplySensor: TemperatureHumiditySensor<Supply>
    
    public init(
      mixedSensor: TemperatureHumiditySensor<Mixed> = .init(),
      postCoilSensor: TemperatureHumiditySensor<PostCoil> = .init(),
      returnSensor: TemperatureHumiditySensor<Return> = .init(),
      supplySensor: TemperatureHumiditySensor<Supply> = .init()
    ) {
      self.mixedSensor = mixedSensor
      self.postCoilSensor = postCoilSensor
      self.returnSensor = returnSensor
      self.supplySensor = supplySensor
    }
    
    public var needsProcessed: Bool {
      mixedSensor.needsProcessed
        || postCoilSensor.needsProcessed
        || returnSensor.needsProcessed
        || supplySensor.needsProcessed
    }
  }
}

extension State.Sensors {
  public struct TemperatureHumiditySensor<Location>: Equatable {
    @TrackedChanges
    public var temperature: Temperature?
    
    @TrackedChanges
    public var humidity: RelativeHumidity?
    
    public var needsProcessed: Bool {
      $temperature.needsProcessed || $humidity.needsProcessed
    }
    
    public init(
      temperature: Temperature? = nil,
      humidity: RelativeHumidity? = nil,
      needsProcessed: Bool = false
    ) {
      self._temperature = .init(wrappedValue: temperature, needsProcessed: needsProcessed)
      self._humidity = .init(wrappedValue: humidity, needsProcessed: needsProcessed)
    }
  }
  
  // MARK: - Temperature / Humidity Sensor Locations
  public enum Mixed { }
  public enum PostCoil { }
  public enum Return { }
  public enum Supply { }
}

// MARK: - Tracked Changes
@propertyWrapper
public struct TrackedChanges<Value> {
  
  private var tracking: TrackingState
  private var value: Value
  
  public var wrappedValue: Value {
    get { value }
    set {
      // fix
      value = newValue
    }
  }
  
  public init(wrappedValue: Value, needsProcessed: Bool = false) {
    self.value = wrappedValue
    self.tracking = needsProcessed ? .needsProcessed : .hasProcessed
  }
  
  enum TrackingState {
    case hasProcessed
    case needsProcessed
  }
  
  public var needsProcessed: Bool {
    get { tracking == .needsProcessed }
    set {
      if newValue {
        tracking = .needsProcessed
      } else {
        tracking = .hasProcessed
      }
    }
  }
  
  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }
}

extension TrackedChanges: Equatable where Value: Equatable { }
