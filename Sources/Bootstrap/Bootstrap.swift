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
///   - autoConnect: A flag whether to auto-connect to the MQTT broker or not.
public func bootstrap(
  eventLoopGroup: EventLoopGroup,
  logger: Logger? = nil,
  autoConnect: Bool = true
) -> EventLoopFuture<DewPointEnvironment> {
  
  logger?.debug("Bootstrapping Dew Point Controller...")
  
  return loadEnvVars(eventLoopGroup: eventLoopGroup, logger: logger)
    .and(loadTopics(eventLoopGroup: eventLoopGroup, logger: logger))
    .makeDewPointEnvironment(eventLoopGroup: eventLoopGroup, logger: logger)
    .connectToMQTTBroker(autoConnect: autoConnect, logger: logger)
}

/// Loads the ``EnvVars`` either using the defualts, from a file in the root directory under `.dewPoint-env` or in the shell / application environment.
///
/// - Parameters:
///   - eventLoopGroup: The event loop group for the application.
///   - logger: An optional logger for debugging.
private func loadEnvVars(
  eventLoopGroup: EventLoopGroup,
  logger: Logger?
) -> EventLoopFuture<EnvVars> {
  
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

// MARK: TODO perhaps make loading from file an option passed in when app is launched.
/// Load the topics from file in application root directory at `.topics`, if available or fall back to the defualt.
///
///  - Parameters:
///   - eventLoopGroup: The event loop group for the application.
///   - logger: An optional logger for debugging.
private func loadTopics(eventLoopGroup: EventLoopGroup, logger: Logger?) -> EventLoopFuture<Topics> {
  
  logger?.debug("Loading topics from file...")
  
  let topicsFilePath = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent(".topics")
  
  let decoder = JSONDecoder()
  
  // Attempt to load the topics from file in root directory.
  let localTopics = (try? Data.init(contentsOf: topicsFilePath))
    .flatMap { try? decoder.decode(Topics.self, from: $0) }
  
  logger?.debug(
    localTopics == nil
      ? "Failed to load topics from file, falling back to defaults."
      : "Done loading topics from file."
  )
  
  // If we were able to load from file use that, else fallback to the defaults.
  return eventLoopGroup.next().makeSucceededFuture(localTopics ?? .init())
}

extension EventLoopFuture where Value == (EnvVars, Topics) {
  
  /// Creates the ``DewPointEnvironment`` for the application after the ``EnvVars`` have been loaded.
  ///
  ///  - Parameters:
  ///   - eventLoopGroup: The event loop group for the application.
  ///   - logger: An optional logger for the application.
  fileprivate func makeDewPointEnvironment(
    eventLoopGroup: EventLoopGroup,
    logger: Logger?
  ) -> EventLoopFuture<DewPointEnvironment> {
      map { envVars, topics in
        let mqttClient = MQTTClient(envVars: envVars, eventLoopGroup: eventLoopGroup, logger: logger)
        return DewPointEnvironment.init(
          envVars: envVars,
          mqttClient: mqttClient,
          topics: topics
        )
      }
  }
}

extension EventLoopFuture where Value == DewPointEnvironment {
  
  /// Connects to the MQTT broker after the ``DewPointEnvironment`` has been setup.
  ///
  /// - Parameters:
  ///   - logger: An optional logger for debugging.
  fileprivate func connectToMQTTBroker(autoConnect: Bool, logger: Logger?) -> EventLoopFuture<DewPointEnvironment> {
    guard autoConnect else { return self }
    return flatMap { environment in
      logger?.debug("Connecting to MQTT Broker...")
      return environment.mqttClient.connect()
        .map { _ in
          logger?.debug("Successfully connected to MQTT Broker...")
          return environment
        }
    }
  }
}

extension MQTTNIO.MQTTClient {
  
  fileprivate convenience init(envVars: EnvVars, eventLoopGroup: EventLoopGroup, logger: Logger?) {
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
