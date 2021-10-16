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
let relayClient = environment.relayClient
let relay = Relay(topic: "frankensystem/relays/switch/relay_1/command")
let tempSensor = TemperatureSensor(topic: "frankensystem/relays/sensor/temperature_-_1/state")

defer {
  logger.debug("Disconnecting")
  _ = try? environment.mqttClient.disconnect().wait()
  try? environment.mqttClient.syncShutdownGracefully()
}

while true {
  logger.debug("Toggling relay.")
  _ = try relayClient.toggle(relay).wait()
  
  logger.debug("Reading temperature sensor.")
  let temp = try environment.temperatureSensorClient.state(tempSensor, .imperial).wait()
  logger.debug("Temperature: \(temp)")
  
  Thread.sleep(forTimeInterval: 5)
}
