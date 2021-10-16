import Models
import MQTTNIO
import NIO

extension RelayClient {
  
  public static func live(client: MQTTClient) -> RelayClient {
    .init(
      toggle: { relay in
        client.publish(relay: relay, state: .toggle)
      },
      turnOn: { relay in
        client.publish(relay: relay, state: .on)
      },
      turnOff: { relay in
        client.publish(relay: relay, state: .off)
      }
    )
  }
}

extension Relay {
  enum State: String {
    case toggle, on, off
  }
}

extension MQTTClient {
  
  func publish(relay: Relay, state: Relay.State, qos: MQTTQoS = .atLeastOnce) -> EventLoopFuture<Void> {
    publish(
      to: relay.topic,
      payload: ByteBufferAllocator().buffer(string: state.rawValue),
      qos: qos
    )
  }
}
