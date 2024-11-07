
@propertyWrapper
public struct TrackedChanges<Value> {
  
  private var tracking: TrackingState
  private var value: Value
  private var isEqual: (Value, Value) -> Bool
  
  public var wrappedValue: Value {
    get { value }
    set {
      // Check if the new value is equal to the old value.
      guard !isEqual(newValue, value) else { return }
      // If it's not equal then set it, as well as set the tracking to `.needsProcessed`.
      value = newValue
      tracking = .needsProcessed
    }
  }
  
  public init(
    wrappedValue: Value,
    needsProcessed: Bool = false,
    isEqual: @escaping (Value, Value) -> Bool
  ) {
    self.value = wrappedValue
    self.tracking = needsProcessed ? .needsProcessed : .hasProcessed
    self.isEqual = isEqual
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

extension TrackedChanges: Equatable where Value: Equatable {
  public static func == (lhs: TrackedChanges<Value>, rhs: TrackedChanges<Value>) -> Bool {
    lhs.wrappedValue == rhs.wrappedValue
      && lhs.needsProcessed == rhs.needsProcessed
  }
  
  public init(
    wrappedValue: Value,
    needsProcessed: Bool = false
  ) {
    self.init(wrappedValue: wrappedValue, needsProcessed: needsProcessed, isEqual: ==)
  }
}
