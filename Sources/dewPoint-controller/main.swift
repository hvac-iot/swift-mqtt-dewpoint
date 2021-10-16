import Bootstrap
import Logging
import Models
import MQTTNIO
import NIO
import RelayClient
import Foundation

var logger = Logger(label: "dewPoint-logger")
logger.logLevel = .debug
logger.debug("Swift Dew Point Controller!")

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let environment = try bootstrap(eventLoopGroup: eventLoopGroup, logger: logger).wait()
let relay = Relay(topic: "frankensystem/relays/switch/relay_1/command")
let tempSensor = TemperatureSensor(topic: "frankensystem/relays/sensor/temperature_-_1/state")
let humiditySensor = HumiditySensor(topic: "frankensystem/relays/sensor/humidity_-_1/state")

defer {
  logger.debug("Disconnecting")
  _ = try? environment.client.shutdown().wait()
  try? environment.mqttClient.syncShutdownGracefully()
}

while true {
//  logger.debug("Toggling relay.")
//  _ = try environment.client.toggleRelay(relay).wait()
  
//  logger.debug("Reading temperature sensor.")
//  let temp = try environment.client.fetchTemperature(tempSensor, .imperial).wait()
//  logger.debug("Temperature: \(temp)")
  
//  logger.debug("Reading humidity sensor.")
//  let humidity = try environment.client.fetchHumidity(humiditySensor).wait()
//  logger.debug("Humdity: \(humidity)")
  
  logger.debug("Fetching dew point...")
  let dp = try environment.client.fetchDewPoint(
    temperature: tempSensor,
    humidity: humiditySensor,
    units: .imperial,
    logger: logger
  ).wait()
  logger.debug("Dew Point: \(dp)")
  
  Thread.sleep(forTimeInterval: 5)
}
