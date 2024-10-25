import EnvVars
import Foundation
import Logging
import MQTTNIO
import NIO

public final class Application {
  
  public let connection: MQTTClientConnection
  public private(set) var isBooted: Bool
  public private(set) var didShutdown: Bool
  public var environment: EnvVars
  public var eventLoopGroupProvider: NIOEventLoopGroupProvider
  public var logger: Logger
  public var storage: Storage
  
  public var client: MQTTClient { connection.client }
  
  public init(
    _ environment: EnvVars = .init(),
    _ eventLoopGroupProvider: NIOEventLoopGroupProvider = .createNew
  ) {
    self.environment = environment
    self.eventLoopGroupProvider = eventLoopGroupProvider
    self.logger = Logger(label: "mqttClient.application")
    self.logger.logLevel = logLevel
    self.connection = .init(envVars: self.environment, eventLoopGroupProvider: self.eventLoopGroupProvider)
    self.storage = Storage()
    self.didShutdown = false
    self.isBooted = false
    self.responder.initialize()
    self.responder.use(.default)
  }
  
  public func start() async throws {
    self.isBooted = true
    await connection.connect()
    // add subscribers and listeners here.
    try await subscribers.initialize(on: connection)
    try await listeners.initialize(on: self)
  }
  
  public func shutdown() async {
    assert(!self.didShutdown, "Application has already shutdown.")
    logger.debug("Application shutting down...")
    
    logger.trace("Shutting down MQTT connection.")
    await connection.shutdown()
    
    logger.trace("Clearing application storage.")
    storage.shutdown()
    storage.clear()
    
    self.didShutdown = true
    logger.trace("Application shutdown complete.")
  }
  
  deinit {
    self.logger.trace("Application deinit...")
    if !self.didShutdown {
      assertionFailure("Application.shutdown() was not called befor Application was deinitialized.")
    }
  }
}

fileprivate let logLevel: Logger.Level = {
  #if DEBUG
  return .trace
  #else
  return .info
  #endif
}()
