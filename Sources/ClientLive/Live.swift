import Foundation
@_exported import Client
import CoreUnitTypes
import Models
import MQTTNIO
import NIO
import Psychrometrics

extension Client {

  // The state passed in here needs to be a class or we get escaping errors in the `addListeners` method.
  public static func live(
    client: MQTTNIO.MQTTClient,
    state: State,
    topics: Topics
  ) -> Self {
    .init(
      addListeners: {
        state.addSensorListeners(to: client, topics: topics)
      },
      connect: {
        client.connect()
          .map { _ in }
      },
      publishSensor: { request in
        client.publishDewPoint(request: request, state: state, topics: topics)
          .publishEnthalpy()
          .setHasProcessed()
      },
      shutdown: {
        client.disconnect()
          .map { try? client.syncShutdownGracefully() }
      },
      subscribe: {
        // Sensor subscriptions
        client.subscribe(to: .sensors(topics: topics))
        .map { _ in }
      }
    )
  }
}

import Logging
import NIOTransportServices
import EnvVars

public class AsyncClient {
  //public static let eventLoopGroup = NIOTSEventLoopGroup()
  public static let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
  public let client: MQTTClient
  public private(set) var shuttingDown: Bool

  var logger: Logger { client.logger }

  public init(envVars: EnvVars, logger: Logger) {
    let config = MQTTClient.Configuration.init(
      version: .v3_1_1,
      userName: envVars.userName,
      password: envVars.password,
      useSSL: false,
      useWebSockets: false,
      tlsConfiguration: nil,
      webSocketURLPath: nil
    )
    self.client = .init(
      host: envVars.host,
      identifier: envVars.identifier,
      eventLoopGroupProvider: .shared(Self.eventLoopGroup),
      logger: logger,
      configuration: config
    )
    self.shuttingDown = false
  }

  public func connect() async {
    do {
      try await self.client.connect()
      self.client.addCloseListener(named: "AsyncClient") { [self] result in
        guard !self.shuttingDown else { return }
        Task {
          self.logger.debug("Connection closed.")
          self.logger.debug("Reconnecting...")
          await self.connect()
        }
      }
      logger.debug("Connection successful.")
    } catch {
      logger.trace("Connection Failed.\n\(error)")
    }
  }

  public func shutdown() async {
    self.shuttingDown = true
    try? await self.client.disconnect()
    try? await self.client.shutdown()
  }

  func addSensorListeners() async {

  }

  // Need to save the recieved values somewhere.
  func addPublishListener<T>(
    topic: String,
    decoding: T.Type
  ) async throws where T: BufferInitalizable {
    _ = try await self.client.subscribe(to: [.init(topicFilter: topic, qos: .atLeastOnce)])
    Task {
      let listener = self.client.createPublishListener()
      for await result in listener {
        switch result {
        case let .success(packet):
          var buffer = packet.payload
          guard let value = T.init(buffer: &buffer) else {
            logger.debug("Could not decode buffer: \(buffer)")
            return
          }
          logger.debug("Recieved value: \(value)")
        case let .failure(error):
          logger.trace("Error:\n\(error)")
        }
      }
    }
  }


  private func publish(string: String, to topic: String) async throws {
    try await self.client.publish(
      to: topic,
      payload: ByteBufferAllocator().buffer(string: string),
      qos: .atLeastOnce
    )
  }

  private func publish(double: Double, to topic: String) async throws {
    let rounded = round(double * 100) / 100
    try await publish(string: "\(rounded)", to: topic)
  }

  func publishDewPoint(_ request: Client.SensorPublishRequest) async throws {
    // fix
    guard let (dewPoint, topic) = request.dewPointData(topics: .init(), units: nil) else { return }
    try await self.publish(double: dewPoint.rawValue, to: topic)
    logger.debug("Published dewpoint: \(dewPoint.rawValue), to: \(topic)")
  }

  func publishEnthalpy(_ request: Client.SensorPublishRequest) async throws {
    // fix
    guard let (enthalpy, topic) = request.enthalpyData(altitude: .seaLevel, topics: .init(), units: nil) else { return }
    try await self.publish(double: enthalpy.rawValue, to: topic)
    logger.debug("Publihsed enthalpy: \(enthalpy.rawValue), to: \(topic)")
  }

  public func publishSensor(_ request: Client.SensorPublishRequest) async throws {
    try await publishDewPoint(request)
    try await publishEnthalpy(request)
  }
}
