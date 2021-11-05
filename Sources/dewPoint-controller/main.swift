import Bootstrap
import ClientLive
import CoreUnitTypes
import Logging
import Models
import MQTTNIO
import NIO
import TopicsLive
import Foundation

var logger: Logger = {
  var logger = Logger(label: "dewPoint-logger")
  logger.logLevel = .debug
  return logger
}()

logger.info("Starting Swift Dew Point Controller!")

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
var environment = try bootstrap(eventLoopGroup: eventLoopGroup, logger: logger, autoConnect: false).wait()

// Set the log level to info only in production mode.
if environment.envVars.appEnv == .production {
  logger.logLevel = .info
}

// Set up the client, topics and state.
environment.topics = .live
let state = State()
let client = Client.live(client: environment.mqttClient, state: state, topics: environment.topics)

defer {
  logger.debug("Disconnecting")
}

// Add topic listeners.
client.addListeners()

while true {
  if !environment.mqttClient.isActive() {
    logger.trace("Connecting to MQTT broker...")
    try client.connect().wait()
    try client.subscribe().wait()
    Thread.sleep(forTimeInterval: 1)
  }
  
  // Check if sensors need processed.
  if state.sensors.needsProcessed {
    logger.debug("Sensor state has changed...")
    if state.sensors.mixedAirSensor.needsProcessed {
      logger.trace("Publishing mixed air sensor.")
      try client.publishSensor(.mixed(state.sensors.mixedAirSensor)).wait()
    }
    if state.sensors.postCoilSensor.needsProcessed {
      logger.trace("Publishing post coil sensor.")
      try client.publishSensor(.postCoil(state.sensors.postCoilSensor)).wait()
    }
    if state.sensors.returnAirSensor.needsProcessed {
      logger.trace("Publishing return air sensor.")
      try client.publishSensor(.return(state.sensors.returnAirSensor)).wait()
    }
    if state.sensors.supplyAirSensor.needsProcessed {
      logger.trace("Publishing supply air sensor.")
      try client.publishSensor(.supply(state.sensors.supplyAirSensor)).wait()
    }
  }

//  logger.debug("Fetching dew point...")
//
//  logger.debug("Published dew point...")
  
  Thread.sleep(forTimeInterval: 5)
}
