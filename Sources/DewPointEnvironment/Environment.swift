import Client
import EnvVars
import Models
import MQTTNIO

// TODO: Remove

public struct DewPointEnvironment: Sendable {

  public var envVars: EnvVars
  public var mqttClient: MQTTNIO.MQTTClient
  public var topics: Topics

  public init(
    envVars: EnvVars,
    mqttClient: MQTTNIO.MQTTClient,
    topics: Topics = .init()
  ) {
    self.envVars = envVars
    self.mqttClient = mqttClient
    self.topics = topics
  }
}
