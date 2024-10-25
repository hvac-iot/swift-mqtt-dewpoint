import Foundation
import Logging
import MQTTNIO
import NIO

public final class Request {
  
  public let application: Application
  public let body: MQTTPublishInfo
  public let logger: Logger
  public var topic: String { body.topicName }
  public var payload: ByteBuffer { body.payload }
 
  public init(
    _ body: MQTTPublishInfo,
    application: Application,
    logger: Logger
  ) {
    self.application = application
    self.body = body
    self.logger = logger
  }
  
  public init(_ body: MQTTPublishInfo, application: Application) {
    self.body = body
    self.application = application
    self.logger = Logger(label: "mqttClient.request")
  }
}

public class RequestStream: AsyncSequence {
  public typealias AsyncIterator = AsyncStream<Element>.AsyncIterator
  public typealias Element = Request
  
  let application: Application
  let topic: String
  let name: String
  let stream: AsyncStream<Element>
  
  public init(application: Application, topic: String) {
    let name = UUID().uuidString
    self.application = application
    self.name = name
    self.topic = topic
    self.stream = AsyncStream { continuation in
      application.client.addPublishListener(named: name) { result in
        switch result {
        case let .success(body):
          guard body.topicName == topic else { break }
//          application.logger.trace("Recieved request for topic: \(topic)")
          continuation.yield(Request(body, application: application))
        case let .failure(error):
          application.logger.trace("Recieved failed request for: \(topic)\n\(error)")
        }
      }
      
      application.connection.client.addShutdownListener(named: name) { _ in
        continuation.finish()
      }
    }
  }
  
  deinit {
    self.application.connection.client.removePublishListener(named: name)
    self.application.connection.client.removeShutdownListener(named: name)
  }
  
  public __consuming func makeAsyncIterator() -> AsyncStream<Element>.AsyncIterator {
    stream.makeAsyncIterator()
  }
  
}

//extension AsyncStream where Element == Request {
//  
//  public static func requestStream(for topic: String, on application: Application) -> Self {
//    .init { continuation in
//      Task {
//        let stream = application.connection.client.createPublishListener()
//          .compactMap { result -> MQTTPublishInfo? in
//            switch result {
//            case let .success(body):
//              return body
//            case let .failure(error):
//              application.logger.warning("Failure in request stream for: \(topic)\n\(error)")
//              return nil
//            }
//          }
//          .filter { $0.topicName == topic }
//          .map(Request.init)
//        
//        for await body in stream {
//          continuation.yield(body)
//        }
//        continuation.finish()
//      }
//    }
//  }
//}
