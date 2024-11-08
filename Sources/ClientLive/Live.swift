@_exported import Client
import CoreUnitTypes
import Foundation
import Models
import MQTTNIO
import NIO
import Psychrometrics

public extension Client {

  // The state passed in here needs to be a class or we get escaping errors in the `addListeners` method.
  static func live(
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
