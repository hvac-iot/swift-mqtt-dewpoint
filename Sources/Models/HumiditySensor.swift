
public struct HumiditySensor: Equatable {
  public var topic: String
  
  public init(topic: String) {
    self.topic = topic
  }
}