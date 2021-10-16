import Foundation
import Client
import CoreUnitTypes
import Models
import MQTTNIO
import NIO

extension Client {
  
  public static func live(client: MQTTClient) -> Self {
    .init(
      fetchHumidity: { sensor in
        client.fetchHumidity(sensor: sensor)
      },
      fetchTemperature: { sensor, units in
        client.fetchTemperature(sensor: sensor, units: units)
      },
      toggleRelay: { relay in
        client.publish(relay: relay, state: .toggle, qos: .atLeastOnce)
      },
      turnOnRelay: { relay in
        client.publish(relay: relay, state: .on, qos: .atLeastOnce)
      },
      turnOffRelay: { relay in
        client.publish(relay: relay, state: .off, qos: .atLeastOnce)
      },
      shutdown: {
        client.disconnect()
      }
    )
  }
}

// MARK: - Helpers
enum TemperatureError: Error {
  case invalidTemperature
}

enum HumidityError: Error {
  case invalidHumidity
}

extension Relay {
  enum State: String {
    case toggle, on, off
  }
}

extension MQTTClient {
  
  fileprivate func publish(relay: Relay, state: Relay.State, qos: MQTTQoS = .atLeastOnce) -> EventLoopFuture<Void> {
    publish(
      to: relay.topic,
      payload: ByteBufferAllocator().buffer(string: state.rawValue),
      qos: qos
    )
  }
  
  // MARK: - TODO it feels like the subscriptions should happen in the `bootstrap` process.
  fileprivate func fetchTemperature(
    sensor: TemperatureSensor,
    units: PsychrometricEnvironment.Units?
  ) -> EventLoopFuture<Temperature> {
    logger.debug("Adding listener for temperature sensor...")
    let subscription = MQTTSubscribeInfoV5.init(
      topicFilter: sensor.topic,
      qos: .atLeastOnce,
      retainAsPublished: true,
      retainHandling: .sendAlways
    )
    return v5.subscribe(to: [subscription])
      .flatMap { _ in
        let promise = self.eventLoopGroup.next().makePromise(of: Temperature.self)
        self.addPublishListener(named: "temperature-sensor", { result in
          switch result.temperature() {
          case let .success(celsius):
            let userUnits = units ?? PsychrometricEnvironment.shared.units
            let temperatureUnits = Temperature.Units.defaultFor(units: userUnits)
            promise.succeed(.init(celsius[temperatureUnits], units: temperatureUnits))
          case let .failure(error):
            promise.fail(error)
          }
        })
        
        return promise.futureResult
      }
  }
  
  // MARK: - TODO it feels like the subscriptions should happen in the `bootstrap` process.
  fileprivate func fetchHumidity(sensor: HumiditySensor) -> EventLoopFuture<RelativeHumidity> {
    logger.debug("Adding listener for humidity sensor...")
    let subscription = MQTTSubscribeInfoV5.init(
      topicFilter: sensor.topic,
      qos: .atLeastOnce,
      retainAsPublished: true,
      retainHandling: .sendAlways
    )
    return v5.subscribe(to: [subscription])
      .flatMap { _ in
        let promise = self.eventLoopGroup.next().makePromise(of: RelativeHumidity.self)
        self.addPublishListener(named: "humidity-sensor", { result in
          switch result.humidity() {
          case let .success(humidity):
            promise.succeed(humidity)
          case let .failure(error):
            promise.fail(error)
          }
        })
        return promise.futureResult
      }
  }
}

extension Result where Success == MQTTPublishInfo, Failure == Error {
  
  fileprivate func humidity() -> Result<RelativeHumidity, Error> {
    flatMap { info in
      var buffer = info.payload
      guard let string = buffer.readString(length: buffer.readableBytes),
            let double = Double(string)
      else {
        return .failure(HumidityError.invalidHumidity)
      }
      return .success(.init(double))
    }
  }
  
  fileprivate func temperature() -> Result<Temperature, Error> {
    flatMap { info in
      var buffer = info.payload
      guard let string = buffer.readString(length: buffer.readableBytes),
            let temperatureValue = Double(string)
      else {
        return .failure(TemperatureError.invalidTemperature)
      }
      return .success(.celsius(temperatureValue))
    }
  }
}
