import Foundation
import MQTTNIO

public protocol Listener {
  var topic: String { get }
  var subscriptionInfo: MQTTSubscribeInfoV5 { get }
  var properties: MQTTProperties { get }
  var handler: (MQTTTopicStream) async -> () { get }
}

extension Listener {
  
  public var subscriptionInfo: MQTTSubscribeInfoV5 {
    .init(topicFilter: topic, qos: .atLeastOnce)
  }
  
  public var properties: MQTTProperties { .init() }
  
  public func initialize(on connection: MQTTClientConnection) async throws {
    _ = try await connection.client.v5.subscribe(
      to: [subscriptionInfo],
      properties: properties
    )
    await handler(.init(connection: connection, topic: topic))
  }
}

extension Application {
  
  public var listeners: Listeners {
    get {
      if let existing = storage[ListenersKey.self] {
        return existing
      } else {
        let value = Listeners()
        storage[ListenersKey.self] = value
        return value
      }
    }
    set {
      storage[ListenersKey.self] = newValue
    }
  }
  
  public struct ListenersKey: StorageKey {
    public typealias Value = Listeners
  }
  
  public struct Listeners {
    private var storage: [Listener] = []
    
    public init() { }
    
    public mutating func use(_ listener: Listener) {
      self.storage.append(listener)
    }
    
    public func value() -> [Listener] {
      storage
    }
    
    public func initialize(on connection: MQTTClientConnection) async throws {
      Task {
        for listener in storage {
          try await listener.initialize(on: connection)
        }
      }
    }
  }
}


public class DefaultListener: Listener {
  public var handler: (MQTTTopicStream) async -> ()
  public let topic: String
  public let subscriptionInfo: MQTTSubscribeInfoV5
  public var middlewares: Application.Middlewares
  
  public init(
    topic: String,
    subscriptionInfo: MQTTSubscribeInfoV5? = nil,
    middlewares: [Middleware] = [],
    handler: @escaping (MQTTTopicStream) async -> ()
  ) {
    self.topic = topic
    self.subscriptionInfo = subscriptionInfo ?? .init(topicFilter: topic, qos: .atLeastOnce)
    self.middlewares = .init(middlewares)
    self.handler = handler
  }
}

//func listener() {
//  DefaultListener(
//    topic: "foo",
//    subscriptionInfo: .init(topicFilter: "foo", qos: .atLeastOnce),
//    middlewares: .init()
//  )
//}
