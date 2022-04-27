import EnvVars
import Foundation
import MQTTNIO
import NIO
import Models

public class MQTTConnectionManager {
  
  let connection: MQTTClientConnection
  private var listeners: [Listener] = []
  private var publishers: [MQTTTopicPublisher] = []
  private var subscribers: [MQTTTopicSubscriber] = []
  
  init(
    envVars: EnvVars,
    eventLoopGroupProvider: NIOEventLoopGroupProvider = .createNew
  ) {
    self.connection = .init(envVars: envVars, eventLoopGroupProvider: eventLoopGroupProvider)
  }
  
  public func registerSubscribers(_ subscribers: MQTTTopicSubscriber...) {
    self.subscribers.append(contentsOf: subscribers)
  }
  
  public func registerSubscribers(_ subscribers: [MQTTTopicSubscriber]) {
    self.subscribers.append(contentsOf: subscribers)
  }
  
  public func registerPublishers(_ publishers: MQTTTopicPublisher...) {
    self.publishers.append(contentsOf: publishers)
  }
  
  public func registerPublishers(_ publishers: [MQTTTopicPublisher]) {
    self.publishers.append(contentsOf: publishers)
  }
  
  public func registerListeners(_ listeners: Listener...) {
    self.listeners.append(contentsOf: listeners)
  }
  
  public func registerListeners(_ listeners: [Listener]) {
    self.listeners.append(contentsOf: listeners)
  }
  
  private var subscribeStream: AsyncStream<Void> {
    AsyncStream { continuation in
      Task {
        for subscription in subscribers {
          await subscription.subscribe(connection: connection)
          continuation.yield()
        }
        continuation.finish()
      }
    }
  }
  
  func subscribe() async {
    for await _ in subscribeStream { }
  }
 
  func listen() {
    Task {
      for listener in listeners {
        connection.logger?.trace("Starting listener.")
        Task {
          await listener.run(on: self)
        }
      }
    }
  }
  
  public func start() async {
    if !connection.client.isActive() {
      await connection.connect()
    }
    await subscribe()
    listen()
    connection.logger?.debug("Started manager...")
  }
  
  public func stop() async {
    await connection.shutdown()
  }
  
  public func publish(_ payload: ByteBuffer, to topic: String) async {
    guard let publisher = publishers.first(where: { $0.publisherInfo.topic == topic }) else {
      connection.logger?.trace("No publisher registered for topic: \(topic)")
      connection.logger?.trace("Using fallback publisher...")
      let fallbackPublisher = MQTTClientConnection.PublisherInfo(topic: topic)
      await fallbackPublisher.publish(payload: payload, on: connection)
      return
    }
    await publisher.publish(payload: payload, on: connection)
  }
  
  public func publish(_ payload: BufferRepresentable, to topic: String) async {
    await publish(payload.buffer, to: topic)
  }
}

extension MQTTConnectionManager {
  
  public struct Listener: MQTTTopicListener {
    public let topic: String
    public let handler: (MQTTConnectionManager, MQTTPublishInfo) async -> ()
    
    public init(
      topic: String,
      handler: @escaping (MQTTConnectionManager, MQTTPublishInfo) async -> ()
    ) {
      self.topic = topic
      self.handler = handler
    }
    
    func run(on manager: MQTTConnectionManager) async {
      let stream = self.topicStream(connection: manager.connection)
      for await payload in stream {
        await handler(manager, payload)
      }
    }
  }
}
