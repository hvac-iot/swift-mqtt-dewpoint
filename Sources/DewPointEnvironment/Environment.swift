import EnvVars
import MQTTNIO
import RelayClient
import TemperatureSensorClient

public struct DewPointEnvironment {
  
  public var mqttClient: MQTTClient
  public var envVars: EnvVars
  public var relayClient: RelayClient
  public var temperatureSensorClient: TemperatureSensorClient
  
  public init(
    mqttClient: MQTTClient,
    envVars: EnvVars,
    relayClient: RelayClient,
    temperatureSensorClient: TemperatureSensorClient
  ) {
    self.mqttClient = mqttClient
    self.envVars = envVars
    self.relayClient = relayClient
    self.temperatureSensorClient = temperatureSensorClient
  }
}
