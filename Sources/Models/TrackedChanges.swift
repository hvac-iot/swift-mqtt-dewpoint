/// A property wrapper that tracks changes of a property.
///
/// This allows values to only publish changes if they have changed since the
/// last time they were recieved.
@propertyWrapper
public struct TrackedChanges<Value> {

  /// The current tracking state.
  private var tracking: TrackingState

  /// The current wrapped value.
  private var value: Value

  /// Used to check if a new value is equal to an old value.
  private var isEqual: (Value, Value) -> Bool

  /// Access to the underlying property that we are wrapping.
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

  /// Create a new property that tracks it's changes.
  ///
  /// - Parameters:
  ///   - wrappedValue: The value that we are wrapping.
  ///   - needsProcessed: Whether this value needs processed (default = false).
  ///   - isEqual: Method to compare old values against new values.
  public init(
    wrappedValue: Value,
    needsProcessed: Bool = false,
    isEqual: @escaping (Value, Value) -> Bool
  ) {
    self.value = wrappedValue
    self.tracking = needsProcessed ? .needsProcessed : .hasProcessed
    self.isEqual = isEqual
  }

  /// Represents whether a wrapped value has changed and needs processed or not.
  enum TrackingState {

    /// The state when nothing has changed and we've already processed the current value.
    case hasProcessed

    /// The state when the value has changed and has not been processed yet.
    case needsProcessed
  }

  /// Check whether the value needs processed.
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

  /// Create a new property that tracks it's changes, using the default equality check.
  ///
  /// - Parameters:
  ///   - wrappedValue: The value that we are wrapping.
  ///   - needsProcessed: Whether this value needs processed (default = false).
  public init(
    wrappedValue: Value,
    needsProcessed: Bool = false
  ) {
    self.init(wrappedValue: wrappedValue, needsProcessed: needsProcessed, isEqual: ==)
  }
}
