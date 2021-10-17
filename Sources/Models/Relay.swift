
/// Represents a relay that can be controlled by the MQTT Broker.
public struct Relay {
  
  /// The topic for the relay.
  public var topic: String
  
  /// Create a new relay at the given topic.
  ///
  /// - Parameters:
  ///   - topic: The topic for commanding the relay.
  public init(topic: String) {
    self.topic = topic
  }
}

public enum Relay2 {
  
  /// The topic to read the current state of the relay from.
  case read(topic: String)
  
  /// The topic to command the relay state.
  case command(topic: String)
}

extension Relay {
  
  /// Represents the different commands that can be sent to a relay.
  public enum State: String {
    
    /// Toggle the relay state on or off based on it's current state.
    case toggle
    
    /// Turn the relay off.
    case off
    
    /// Turn the relay on.
    case on
  }
}
