
/// Represents a sensor that provides a reading.
public struct Sensor<Reading>: Equatable {
  
  /// The topic to retrieve the reading from.
  public var topic: String
  
  /// Create a new sensor for the given topic.
  ///
  /// - Parameters:
  ///   - topic: The topic to retrieve the readings from.
  public init(topic: String) {
    self.topic = topic
  }
}
