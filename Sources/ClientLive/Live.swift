import Foundation
import Client
import CoreUnitTypes
import Models
import MQTTNIO
import NIO

extension Client.MQTTClient {
  
  /// Creates the live implementation of our ``Client.MQTTClient`` for the application.
  ///
  /// - Parameters:
  ///   - client: The ``MQTTNIO.MQTTClient`` used to send and recieve messages from the MQTT Broker.
  public static func live(client: MQTTNIO.MQTTClient) -> Self {
    .init(
      fetchHumidity: { sensor in
        client.fetch(sensor: sensor)
      },
      fetchTemperature: { sensor, units in
        client.fetch(sensor: sensor)
          .convertIfNeeded(to: units)
      },
      setRelay: { relay, state in
        client.set(relay: relay, to: state)
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
