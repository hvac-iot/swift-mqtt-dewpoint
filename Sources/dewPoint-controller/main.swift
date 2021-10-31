import Bootstrap
import CoreUnitTypes
import Logging
import Models
import MQTTNIO
import NIO
import Foundation

var logger: Logger = {
  var logger = Logger(label: "dewPoint-logger")
  logger.logLevel = .info
  return logger
}()

logger.info("Starting Swift Dew Point Controller!")

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let environment = try bootstrap(eventLoopGroup: eventLoopGroup, logger: logger).wait()

// Set the log level to info only in production mode.
if environment.envVars.appEnv == .production {
  logger.logLevel = .info
}

//let relay = Relay(topic: environment.topics.commands.relays.dehumidification1)
//let tempSensor = Sensor<Temperature>(topic: environment.topics.sensors.returnAirSensor.temperature)
//let humiditySensor = Sensor<RelativeHumidity>(topic: environment.topics.sensors.returnAirSensor.humidity)

defer {
  logger.debug("Disconnecting")
//  try? environment.mqttClient.shutdown().wait()
}

while true {
//  let temp = try environment.mqttClient.fetchTemperature(tempSensor, .imperial).wait()
//  logger.debug("Temp: \(temp.rawValue)")
//
//  logger.debug("Fetching set-point...")
//  let sp = try environment.mqttClient.fetchSetPoint(\.dehumidify.highDewPoint).wait()
//  logger.debug("Set point: \(sp)")
//
  logger.debug("Fetching dew point...")

//  let dp = try environment.mqttClient.currentDewPoint(
//    temperature: tempSensor,
//    humidity: humiditySensor,
//    units: .imperial
//  ).wait()

//  logger.info("Dew Point: \(dp.rawValue) \(dp.units.symbol)")

//  try environment.mqttClient.publish(
//    dewPoint: dp,
//    to: environment.topics.sensors.returnAirSensor.dewPoint
//  ).wait()

  logger.debug("Published dew point...")
  
  Thread.sleep(forTimeInterval: 5)
}
