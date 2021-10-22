import Foundation
@_exported import Client
import CoreUnitTypes
import Models
import MQTTNIO
import NIO

extension Client.MQTTClient {
  
  /// Creates the live implementation of our ``Client.MQTTClient`` for the application.
  ///
  /// - Parameters:
  ///   - client: The ``MQTTNIO.MQTTClient`` used to send and recieve messages from the MQTT Broker.
  public static func live(client: MQTTNIO.MQTTClient, topics: Topics) -> Self {
    .init(
      fetchHumidity: { sensor in
        client.fetch(sensor: sensor)
          .debug(logger: client.logger)
      },
      fetchSetPoint: { setPointKeyPath in
        client.fetch(client.mqttSubscription(topic: topics.setPoints[keyPath: setPointKeyPath]))
          .debug(logger: client.logger)
      },
      fetchTemperature: { sensor, units in
        client.fetch(sensor: sensor)
          .debug(logger: client.logger)
          .convertIfNeeded(to: units)
          .debug(logger: client.logger)
      },
      setRelay: { relayKeyPath, state in
        client.set(relay: topics.commands.relays[keyPath: relayKeyPath], to: state)
      },
      shutdown: {
        client.disconnect()
          .map { try? client.syncShutdownGracefully() }
      },
      publishDewPoint: { dewPoint, topic in
        client.publish(
          to: topic,
          payload: ByteBufferAllocator().buffer(string: "\(dewPoint.rawValue)"),
          qos: .atLeastOnce
        )
      }
    )
  }
}
