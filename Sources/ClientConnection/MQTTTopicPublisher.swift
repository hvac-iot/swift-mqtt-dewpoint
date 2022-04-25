import Foundation
import Models
import MQTTNIO
import NIO

extension MQTTClientConnection {
  
  public struct PublisherInfo: Equatable {
    public var topic: String
    public var qos: MQTTQoS
    public var retain: Bool
    
    public init(
      topic: String,
      qos: MQTTQoS = .atLeastOnce,
      retain: Bool = false
    ) {
      self.topic = topic
      self.qos = qos
      self.retain = retain
    }
  }
}

public protocol MQTTTopicPublisher {
  var publisherInfo: MQTTClientConnection.PublisherInfo { get }
}

extension MQTTClientConnection.PublisherInfo: MQTTTopicPublisher {
  
  public var publisherInfo: MQTTClientConnection.PublisherInfo { self }
}

extension MQTTTopicPublisher {
  
  public func publish(
    payload: ByteBuffer,
    on connection: MQTTClientConnection
  ) async {
    do {
      _ = try await connection.client.publish(
        to: publisherInfo.topic,
        payload: payload,
        qos: publisherInfo.qos,
        retain: publisherInfo.retain
      )
      connection.logger?.trace("Published to: \(publisherInfo.topic)")
    } catch {
      connection.logger?.trace("Failed to publish to: \(publisherInfo.topic)\n\(error)")
    }
  }
  
  public func publish(
    payload: BufferRepresentable,
    on connection: MQTTClientConnection
  ) async {
    await self.publish(payload: payload.buffer, on: connection)
  }
}
