import Foundation
import MQTTNIO

public protocol MQTTTopicSubscriber {
  var subscriberInfo: MQTTClientConnection.SubscriberInfo { get }
}

extension MQTTTopicSubscriber {
  
  public func subscribe(connection: MQTTClientConnection) async {
    do {
      _ = try await connection.client.v5.subscribe(
        to: [subscriberInfo.mqttSubscriberInfo],
        properties: subscriberInfo.properties
      )
      connection.logger?.trace("Subscribed to: \(subscriberInfo.topic)")
    } catch {
      connection.logger?.trace("Failed to subscribe:\n\(error)")
    }
  }
}


extension MQTTClientConnection {
  
  public struct SubscriberInfo: MQTTTopicSubscriber {
   
    public var topic: String
    public var properties: MQTTProperties
    public var qos: MQTTQoS
    
    public init(
      topic: String,
      properties: MQTTProperties = .init(),
      qos: MQTTQoS = .atLeastOnce
    ) {
      self.topic = topic
      self.properties = properties
      self.qos = qos
    }
    
    public var subscriberInfo: MQTTClientConnection.SubscriberInfo { self }
    
    // helpers.
    var mqttSubscriberInfo: MQTTSubscribeInfoV5 {
      .init(topicFilter: topic, qos: qos)
    }
  }
}

extension MQTTClientConnection.SubscriberInfo: Equatable {
  public static func == (lhs: MQTTClientConnection.SubscriberInfo, rhs: MQTTClientConnection.SubscriberInfo) -> Bool {
    lhs.topic == rhs.topic
  }
}

