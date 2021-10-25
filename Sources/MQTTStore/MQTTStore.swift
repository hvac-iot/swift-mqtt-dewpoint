import Logging
import Foundation
import MQTTNIO
import NIO

// TODO: This works and allows tests to complete, but should potentially be simplified.

typealias PublishTopicHandler<State> = (inout State, Result<MQTTPublishInfo, Error>) -> Void

struct ServerDetails {
    let identifier: String
    let hostname: String
    let port: Int
    let version: MQTTClient.Version
    let cleanSession: Bool
    let useTLS: Bool
    let useWebSocket: Bool
    let webSocketUrl: String
    let username: String?
    let password: String?
}

class MQTTStore<State> {
  typealias Subscription = (topic: String, onPublish: PublishTopicHandler<State>)
  
  var state: State
  var subscriptions: [Subscription]
  var client: MQTTClient?
  var serverDetails: ServerDetails
  var eventLoopGroup: EventLoopGroup
  var logger: Logger?
  
  init(
    state: State,
    subscriptions: [Subscription],
    serverDetails: ServerDetails,
    eventLoopGroup: EventLoopGroup,
    logger: Logger? = nil
  ) {
    self.state = state
    self.subscriptions = subscriptions
    self.serverDetails = serverDetails
    self.eventLoopGroup = eventLoopGroup
    self.logger = logger
    self.createClient()
  }
  
  private func createClient() {
    let client = MQTTClient(
      host: serverDetails.hostname,
      identifier: serverDetails.identifier,
      eventLoopGroupProvider: .shared(eventLoopGroup),
      logger: logger,
      configuration: .init(
        version: serverDetails.version,
        userName: serverDetails.username,
        password: serverDetails.password,
        useSSL: serverDetails.useTLS,
        useWebSockets: serverDetails.useWebSocket,
        webSocketURLPath: serverDetails.webSocketUrl
      )
    )
    for subscription in subscriptions {
      client.addPublishListener(
        named: subscription.topic,
        { result in subscription.onPublish(&self.state, result) }
      )
    }
    self.client = client
  }
  
  func createSubscriptions() -> EventLoopFuture<Void> {
    let subscriptionInfo = subscriptions.map { MQTTSubscribeInfo.init(topicFilter: $0.0, qos: .atLeastOnce) }
    return client?.subscribe(to: subscriptionInfo).map { _ in } ?? eventLoopGroup.next().makeSucceededVoidFuture()
  }
  
  func connect(cleanSession: Bool) -> EventLoopFuture<Bool> {
    client?.connect(cleanSession: cleanSession) ?? eventLoopGroup.next().makeSucceededFuture(false)
  }
  
  func connectAndSubscribe(cleanSession: Bool) -> EventLoopFuture<Void> {
    connect(cleanSession: cleanSession)
      .flatMap{ _ in self.createSubscriptions() }
  }
  
  func destroy() -> EventLoopFuture<Void> {
    guard let client = client else {
      return eventLoopGroup.next().makeSucceededVoidFuture()
    }
    return client.disconnect().map { _ in
      try? self.client?.syncShutdownGracefully()
      self.client = nil
    }
  }
}
