import Foundation
import Logging
import MQTTNIO
import NIO

public final class Request {
  public let request: MQTTPublishInfo
  public let logger: Logger
  
  public var topic: String { request.topicName }
 
  public init(
    request: MQTTPublishInfo,
    logger: Logger = .init(label: "mqttClient.request")
  ) {
    self.request = request
    self.logger = logger
  }
}
