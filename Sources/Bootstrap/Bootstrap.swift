import ClientLive
import DewPointEnvironment
import EnvVars
import Logging
import Foundation
import Models
import MQTTNIO
import NIO

/// Sets up the application environment and connections required.
///
/// - Parameters:
///   - eventLoopGroup: The event loop group for the application.
///   - logger: An optional logger for debugging.
public func bootstrap(
  eventLoopGroup: EventLoopGroup,
  logger: Logger? = nil
) -> EventLoopFuture<DewPointEnvironment> {
  
  logger?.debug("Bootstrapping Dew Point Controller...")
  
  return loadEnvVars(eventLoopGroup: eventLoopGroup, logger: logger)
    .makeDewPointEnvironment(eventLoopGroup: eventLoopGroup, logger: logger)
    .connectToMQTTBroker(logger: logger)
}

/// Loads the ``EnvVars`` either using the defualts, from a file in the root directory under `.dewPoint-env` or in the shell / application environment.
///
/// - Parameters:
///   - eventLoopGroup: The event loop group for the application.
///   - logger: An optional logger for debugging.
private func loadEnvVars(eventLoopGroup: EventLoopGroup, logger: Logger?) -> EventLoopFuture<EnvVars> {
  
  logger?.debug("Loading env vars...")
  
  let envFilePath = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent(".dewPoint-env")
  
  let decoder = JSONDecoder()
  let encoder = JSONEncoder()
  
  let defaultEnvVars = EnvVars()
  
  let defaultEnvDict = (try? encoder.encode(defaultEnvVars))
    .flatMap { try? decoder.decode([String: String].self, from: $0) }
    ?? [:]
  
  // Read from file `.dewPoint-env` file if it exists.
  let localEnvVarsDict = (try? Data(contentsOf: envFilePath))
    .flatMap { try? decoder.decode([String: String].self, from: $0) }
    ?? [:]
    
  // Merge with variables in the shell environment.
  let envVarsDict = defaultEnvDict
    .merging(localEnvVarsDict, uniquingKeysWith: { $1 })
    .merging(ProcessInfo.processInfo.environment, uniquingKeysWith: { $1 })
  
  // Produces the final env vars from the merged items or uses defaults if something
  // went wrong.
  let envVars = (try? JSONSerialization.data(withJSONObject: envVarsDict))
    .flatMap { try? decoder.decode(EnvVars.self, from: $0) }
  ?? defaultEnvVars
  
  logger?.debug("Done loading env vars...")
  return eventLoopGroup.next().makeSucceededFuture(envVars)
}

extension EventLoopFuture where Value == EnvVars {
  
  /// Creates the ``DewPointEnvironment`` for the application after the ``EnvVars`` have been loaded.
  ///
  ///  - Parameters:
  ///   - eventLoopGroup: The event loop group for the application.
  ///   - logger: An optional logger for the application.
  fileprivate func makeDewPointEnvironment(
    eventLoopGroup: EventLoopGroup,
    logger: Logger?
  ) -> EventLoopFuture<DewPointEnvironment> {
      map { envVars in
        let nioClient = MQTTClient(envVars: envVars, eventLoopGroup: eventLoopGroup, logger: logger)
        return DewPointEnvironment.init(
          mqttClient: .live(client: nioClient),
          envVars: envVars,
          nioClient: nioClient,
          topics: .init(envVars: envVars)
        )
      }
  }
}

extension EventLoopFuture where Value == DewPointEnvironment {
  
  /// Connects to the MQTT broker after the ``DewPointEnvironment`` has been setup.
  ///
  /// - Parameters:
  ///   - logger: An optional logger for debugging.
  fileprivate func connectToMQTTBroker(logger: Logger?) -> EventLoopFuture<DewPointEnvironment> {
    flatMap { environment in
      logger?.debug("Connecting to MQTT Broker...")
      return environment.nioClient.connect()
        .map { _ in
          logger?.debug("Successfully connected to MQTT Broker...")
          return environment
        }
    }
  }
}

// MARK: - Helpers

extension MQTTClient {
  
  convenience init(envVars: EnvVars, eventLoopGroup: EventLoopGroup, logger: Logger?) {
    self.init(
      host: envVars.host,
      port: envVars.port != nil ? Int(envVars.port!) : nil,
      identifier: envVars.identifier,
      eventLoopGroupProvider: .shared(eventLoopGroup),
      logger: logger,
      configuration: .init(
        version: .v5_0,
        userName: envVars.userName,
        password: envVars.password
      )
    )
  }
}

// MARK: - TODO Make topics loadable from a file in the root directory.
extension Topics {
  
  init(envVars: EnvVars) {
    self.init(
      sensors: .init(
        temperature: envVars.temperatureSensor,
        humidity: envVars.humiditySensor,
        dewPoint: envVars.dewPointTopic
      ),
      relays: .init(
        dehumidification1: envVars.dehumidificationStage1Relay,
        dehumidification2: envVars.dehumidificationStage2Relay,
        humidification: envVars.humidificationRelay
      )
    )
  }
}
