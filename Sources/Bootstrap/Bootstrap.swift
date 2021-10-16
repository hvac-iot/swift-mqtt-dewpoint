import DewPointEnvironment
import EnvVars
import Logging
import Foundation
import MQTTNIO
import NIO
import RelayClient
import TemperatureSensorClient

public func bootstrap(
  eventLoopGroup: EventLoopGroup,
  logger: Logger? = nil
) -> EventLoopFuture<DewPointEnvironment> {
  logger?.debug("Bootstrapping Dew Point Controller...")
  return loadEnvVars(eventLoopGroup: eventLoopGroup, logger: logger)
    .map { (envVars) -> DewPointEnvironment in
      let mqttClient = MQTTClient(envVars: envVars, eventLoopGroup: eventLoopGroup, logger: logger)
      return DewPointEnvironment.init(
        mqttClient: mqttClient,
        envVars: envVars,
        relayClient: .live(client: mqttClient),
        temperatureSensorClient: .live(client: mqttClient)
      )
    }
    .flatMap { environment in
      environment.mqttClient.logger.debug("Connecting to MQTT broker...")
      return environment.mqttClient.connect()
        .map { _ in environment }
    }
}

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
