import Dependencies
import Foundation
import Logging
import Models
import MQTTConnectionService
import MQTTNIO
import NIO
import PsychrometricClientLive
import SensorsClientLive
import ServiceLifecycle

@main
struct Application {

  /// The main entry point of the application.
  static func main() async throws {
    let eventloopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    var logger = Logger(label: "dewpoint-controller")
    logger.logLevel = .trace

    logger.info("Starting dewpoint-controller!")

    let environment = loadEnvVars(logger: logger)

    if environment.appEnv == .production {
      logger.debug("Updating logging level to info.")
      logger.logLevel = .info
    }

    let mqtt = MQTTClient(
      envVars: environment,
      eventLoopGroup: eventloopGroup,
      logger: logger
    )

    let mqttConnection = MQTTConnectionService(client: mqtt)
    try await withDependencies {
      $0.psychrometricClient = PsychrometricClient.liveValue
      $0.sensorsClient = .live(client: mqtt)
    } operation: {
      let sensors = SensorsService(sensors: .live)

      var serviceGroupConfiguration = ServiceGroupConfiguration(
        services: [
          mqttConnection,
          sensors
        ],
        gracefulShutdownSignals: [.sigterm, .sigint],
        logger: logger
      )
      serviceGroupConfiguration.maximumCancellationDuration = .seconds(5)
      serviceGroupConfiguration.maximumGracefulShutdownDuration = .seconds(10)

      let serviceGroup = ServiceGroup(configuration: serviceGroupConfiguration)

      try await serviceGroup.run()
    }
  }
}

// MARK: - Helpers

private func loadEnvVars(logger: Logger) -> EnvVars {
  let defaultEnvVars = EnvVars()
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  let defaultEnvDict = (try? encoder.encode(defaultEnvVars))
    .flatMap { try? decoder.decode([String: String].self, from: $0) }
    ?? [:]

  let envVarsDict = defaultEnvDict
    .merging(ProcessInfo.processInfo.environment, uniquingKeysWith: { $1 })

  let envVars = (try? JSONSerialization.data(withJSONObject: envVarsDict))
    .flatMap { try? decoder.decode(EnvVars.self, from: $0) }
    ?? defaultEnvVars

  logger.debug("Done loading EnvVars...")

  return envVars
}

private extension MQTTNIO.MQTTClient {
  convenience init(envVars: EnvVars, eventLoopGroup: EventLoopGroup, logger: Logger?) {
    self.init(
      host: envVars.host,
      port: envVars.port != nil ? Int(envVars.port!) : nil,
      identifier: envVars.identifier,
      eventLoopGroupProvider: .shared(eventLoopGroup),
      logger: logger,
      configuration: .init(
        version: .v3_1_1,
        disablePing: false,
        userName: envVars.userName,
        password: envVars.password
      )
    )
  }
}

private extension Array where Element == TemperatureAndHumiditySensor {
  static var live: Self {
    TemperatureAndHumiditySensor.Location.allCases.map { location in
      TemperatureAndHumiditySensor(location: location)
    }
  }
}
