import Foundation
import MQTTNIO
import NIO
import Models

extension Application {
  
  public var publishers: Publishers {
    get {
      if let existing = storage[PublishersKey.self] {
        return existing
      } else {
        let new = Publishers()
        storage[PublishersKey.self] = new
        return new
       }
    }
    set {
      storage[PublishersKey.self] = newValue
    }
  }
  
  public func publish(
    _ payload: ByteBuffer,
    to topic: String
  ) async {
//    let task = Task {
      var publishers = self.publishers.filter(topic: topic)
      if publishers.count == 0 {
        publishers = [BasicPublisher(topic: topic)]
      }
      for publisher in publishers {
        await publisher.publish(payload: payload, on: connection)
      }
//    }
    
//    await task.value
  }
  
  public func publish(
    _ payload: BufferRepresentable,
    to topic: String
  ) async {
    await publish(payload.buffer, to: topic)
  }
  
  public struct Publishers {
    private var storage: [MQTTTopicPublisher] = []
    
    public init() { }
    
    public mutating func use(_ publisher: MQTTTopicPublisher) {
      self.storage.append(publisher)
    }
    
    public func value() -> [MQTTTopicPublisher] {
      storage
    }
    
    public func filter(topic: String) -> [MQTTTopicPublisher] {
      storage.filter { $0.publisherInfo.topic == topic }
    }
  }
  
  private struct PublishersKey: StorageKey {
    typealias Value = Publishers
  }
}

public struct BasicPublisher: MQTTTopicPublisher {
//  public let topic: String
  public var publisherInfo: MQTTClientConnection.PublisherInfo
  
  public init(topic: String, qos: MQTTQoS = .atLeastOnce, retain: Bool = false) {
//    self.topic = topic
    self.publisherInfo = .init(topic: topic, qos: qos, retain: retain)
  }
}
