import CoreUnitTypes
import Foundation
import MQTTNIO

extension TemperatureSensorClient {
  
  public static func live(client: MQTTClient) -> TemperatureSensorClient {
    .init(
      state: { sensor, units in
        client.logger.debug("Adding listener for temperature sensor...")
        let subscription = MQTTSubscribeInfoV5.init(topicFilter: sensor.topic, qos: .atLeastOnce)
        return client.v5.subscribe(to: [subscription])
          .flatMap { _ in
            let promise = client.eventLoopGroup.next().makePromise(of: Temperature.self)
            client.addPublishListener(named: "temperature-sensor", { result in
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
    )
  }
}

public enum TemperatureError: Error {
  case invalidTemperature
}

// MARK: - Helpers
extension Result where Success == MQTTPublishInfo, Failure == Error {
  
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
