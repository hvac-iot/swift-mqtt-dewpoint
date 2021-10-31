import Foundation
@_exported import Client
import CoreUnitTypes
import Models
import MQTTNIO
import NIO
import Psychrometrics

extension Client {
  
  // The state passed in here needs to be a class or we get escaping errors in the `addListeners` method.
  public static func live(
    client: MQTTNIO.MQTTClient,
    state: State,
    topics: Topics
  ) -> Self {
    .init(
      addListeners: {
        state.addSensorListeners(to: client, topics: topics)
      },
      connect: {
        client.connect()
          .map { _ in }
      },
      publishSensor: { request in
        client.publishDewPoint(request: request, state: state, topics: topics)
          .publishEnthalpy()
          .setHasProcessed()
      },
      shutdown: {
        client.disconnect()
          .map { try? client.syncShutdownGracefully() }
      },
      subscribe: {
        // Sensor subscriptions
        client.subscribe(to: .sensors(topics: topics))
        .map { _ in }
      }
    )
  }
}
