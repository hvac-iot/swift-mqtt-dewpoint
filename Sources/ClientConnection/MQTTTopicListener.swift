import Foundation
import MQTTNIO

public protocol MQTTTopicListener {
  var topic: String { get }
}

extension MQTTTopicListener {
  
  public func topicStream(connection: MQTTClientConnection) -> MQTTTopicStream {
    MQTTTopicStream(connection: connection, topic: topic)
  }
  
//  public func topicStream(manager: MQTTConnectionManager) -> MQTTTopicStream {
//    MQTTTopicStream(connection: manager.connection, topic: topic)
//  }
}

public class MQTTTopicStream: AsyncSequence {
  public typealias AsyncIterator = AsyncStream<Element>.AsyncIterator
  public typealias Element = MQTTPublishInfo
  
  let connection: MQTTClientConnection
  let topic: String
  let name: String
  let stream: AsyncStream<Element>
  
  init(connection: MQTTClientConnection, topic: String) {
    let name = UUID().uuidString
    self.connection = connection
    self.name = name
    self.topic = topic
    self.stream = AsyncStream { continuation in
      connection.client.addPublishListener(named: name) { result in
        switch result {
        case let .success(payload):
          guard payload.topicName == topic else { break }
          connection.logger?.trace("Recieved payload for topic:\(payload.topicName)")
          continuation.yield(payload)
        case let .failure(error):
          connection.logger?.trace("Failed:\n\(error)")
        }
      }
      connection.client.addShutdownListener(named: name) { _ in
        continuation.finish()
      }
    }
  }
  
  deinit {
    self.connection.client.removePublishListener(named: name)
    self.connection.client.removeShutdownListener(named: name)
  }
  
  public __consuming func makeAsyncIterator() -> AsyncStream<Element>.AsyncIterator {
    return self.stream.makeAsyncIterator()
  }
}
