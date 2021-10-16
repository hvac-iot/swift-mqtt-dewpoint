import Client
import EnvVars
import MQTTNIO

public struct DewPointEnvironment {
  
  public var client: Client
  public var envVars: EnvVars
  public var mqttClient: MQTTClient
  
  public init(
    client: Client,
    envVars: EnvVars,
    mqttClient: MQTTClient
  ) {
    self.mqttClient = mqttClient
    self.envVars = envVars
    self.client = client
  }
}
