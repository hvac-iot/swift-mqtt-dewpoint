import MQTTNIO

extension Application {
  
  public var subscribers: Subscribers {
    get {
      if let existing = storage[SubscribersKey.self] {
        return existing
      } else {
        let new = Subscribers()
        storage[SubscribersKey.self] = new
        return new
      }
    }
    set {
      storage[SubscribersKey.self] = newValue
    }
  }
  
  private struct SubscribersKey: StorageKey {
    typealias Value = Subscribers
  }
  
  public struct Subscribers {
    private var storage: [MQTTTopicSubscriber] = []
    
    public init() { }
    
    public mutating func use(_ subscriber: MQTTTopicSubscriber) {
      storage.append(subscriber)
    }
    
    public func initialize(on connection: MQTTClientConnection) async throws {
      for subscriber in storage {
        try await subscriber.trySubscribe(connection: connection)
      }
    }
  }
}

