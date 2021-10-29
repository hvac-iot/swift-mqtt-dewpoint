import Foundation
import CoreUnitTypes

public struct State: Equatable {
  
  @TrackedChanges
  public var temperature: Temperature?
  
  @TrackedChanges
  public var humidity: RelativeHumidity?
  
  public init(
    temperature: Temperature? = nil,
    humidity: RelativeHumidity? = nil,
    needsProcessed: Bool = false
  ) {
    self._temperature = .init(wrappedValue: temperature, needsProcessed: needsProcessed)
    self._humidity = .init(wrappedValue: humidity, needsProcessed: needsProcessed)
  }
  
  public var needsProcessed: Bool {
    $temperature.needsProcessed || $humidity.needsProcessed
  }
}

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
