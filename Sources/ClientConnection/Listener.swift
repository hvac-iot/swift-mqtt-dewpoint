import Foundation
import MQTTNIO

public protocol Listener {
  var topic: String { get }
  var subscriptionInfo: MQTTSubscribeInfoV5 { get }
  var properties: MQTTProperties { get }
  var responder: Responder { get }
}

extension Listener {
  
  public var subscriptionInfo: MQTTSubscribeInfoV5 {
    .init(topicFilter: topic, qos: .atLeastOnce)
  }
  
  public var properties: MQTTProperties { .init() }
  
  internal func initialize(
    on application: Application
  ) async throws {
    
    application.logger.trace("Registering listener for topic: \(topic).")
    
    _ = try await application.client.v5.subscribe(
      to: [subscriptionInfo],
      properties: properties
    )
    
    application.logger.trace("Sucessfully subscribed to topic: \(topic)")
    
    Task {
      let stream = RequestStream(application: application, topic: topic)
      for await request in stream {
        _ = try await application.responder.respond(to: request)
      }
    }
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
    
    internal func initialize(on application: Application) async throws {
      Task {
        for listener in storage {
          try await listener.initialize(on: application)
        }
      }
    }
  }
}


public class BasicListener: Listener {
  
  public let topic: String
  public let subscriptionInfo: MQTTSubscribeInfoV5
  public let responder: Responder
  
  public init(
    topic: String,
    subscriptionInfo: MQTTSubscribeInfoV5? = nil,
    middleware: [Middleware] = [],
    responder: Responder
  ) {
    self.topic = topic
    self.subscriptionInfo = subscriptionInfo ?? .init(topicFilter: topic, qos: .atLeastOnce)
    self.responder = middleware.makeResponder(chainingTo: responder)
  }
  
  public convenience init(
    topic: String,
    subscriptionInfo: MQTTSubscribeInfoV5? = nil,
    middleware: [Middleware] = [],
    responder: @escaping (Request) async throws -> Response
  ) {
    self.init(
      topic: topic,
      subscriptionInfo: subscriptionInfo,
      middleware: middleware,
      responder: ListenerResponder(closure: responder)
    )
  }
}

fileprivate struct ListenerResponder: Responder {

  let closure: (Request) async throws -> Response

  func respond(to request: Request) async throws -> Response {
    try await closure(request)
  }
}
