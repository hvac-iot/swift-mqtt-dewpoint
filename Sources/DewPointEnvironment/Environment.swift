import Client
import EnvVars
import Models
import MQTTNIO

public struct DewPointEnvironment {
  
  public var mqttClient: Client.MQTTClient
  public var envVars: EnvVars
  public var nioClient: MQTTNIO.MQTTClient
  public var topics: Topics
  
  public init(
    mqttClient: Client.MQTTClient,
    envVars: EnvVars,
    nioClient: MQTTNIO.MQTTClient,
    topics: Topics = .init()
  ) {
    self.mqttClient = mqttClient
    self.envVars = envVars
    self.nioClient = nioClient
    self.topics = topics
  }
}
