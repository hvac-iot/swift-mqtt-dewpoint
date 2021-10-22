import CoreUnitTypes
import Logging
import Models
import MQTTNIO
import NIO

/// Represents a type that can be initialized by a ``ByteBuffer``.
protocol BufferInitalizable {
  init?(buffer: inout ByteBuffer)
}

extension Temperature: BufferInitalizable {
  
  init?(buffer: inout ByteBuffer) {
    guard let string = buffer.readString(length: buffer.readableBytes, encoding: .utf8),
            let value = Double(string)
    else {
      return nil
    }
    self.init(value, units: .celsius)
  }
}

extension RelativeHumidity: BufferInitalizable {
  
  init?(buffer: inout ByteBuffer) {
    guard let string = buffer.readString(length: buffer.readableBytes, encoding: .utf8),
          let value = Double(string)
    else {
      return nil
    }
    self.init(value)
  }
}

/// Represents errors thrown while communicating with the MQTT Broker.
enum MQTTError: Error {
  
  /// Sensor error.
  case sensor(reason: String, error: Error?)
  
  /// Relay error.
  case relay(reason: String, error: Error?)
}

protocol FetchableTopic {
  associatedtype Value: BufferInitalizable
  var topic: String { get }
}

extension Double: BufferInitalizable {
  
  init?(buffer: inout ByteBuffer) {
    guard let string = buffer.readString(length: buffer.readableBytes) else {
      return nil
    }
    self.init(string)
  }
}

//extension SetPoint: FetchableTopic {
//  typealias Value = Double
//}

extension Sensor: FetchableTopic where Reading: BufferInitalizable {
  typealias Value = Reading
}

extension MQTTNIO.MQTTClient {
  
  func mqttSubscription(topic: String, qos: MQTTQoS = .atLeastOnce, retainAsPublished: Bool = true, retainHandling: MQTTSubscribeInfoV5.RetainHandling = .sendAlways)  -> MQTTSubscribeInfoV5 {
    .init(topicFilter: topic, qos: qos, retainAsPublished: retainAsPublished, retainHandling: retainHandling)
  }
  
  func fetch<Value>(
    _ subscription: MQTTSubscribeInfoV5
  ) -> EventLoopFuture<Value> where Value: BufferInitalizable {
    logger.debug("Fetching data for: \(subscription.topicFilter)")
    return v5.subscribe(to: [subscription])
      .flatMap { _ in
        let promise = self.eventLoopGroup.next().makePromise(of: Value.self)
        self.addPublishListener(named: subscription.topicFilter + "-listener") { result in
          
          result.mapBuffer(to: Value.self)
            .unwrap(or: MQTTError.sensor(reason: "Invalid sensor reading", error: nil))
            .fullfill(promise: promise)
          
          self.logger.debug("Done fetching data for: \(subscription.topicFilter)")
        }
        
        return promise.futureResult
      }
  }
  
  /// Fetch a sensor state and convert it appropriately, when the sensor type is ``BufferInitializable``.
  ///
  /// - Parameters:
  ///   - sensor: The sensor to fetch the state of.
  func fetch<S>(
    sensor: Sensor<S>
  ) -> EventLoopFuture<S> where S: BufferInitalizable {
    return fetch(mqttSubscription(topic: sensor.topic))
  }
  
  func fetch(setPoint: KeyPath<Topics.SetPoints, String>, setPoints: Topics.SetPoints) -> EventLoopFuture<Double> {
//    logger.debug("Fetching data for set point: \(setPoint.topic)")
    return fetch(mqttSubscription(topic: setPoints[keyPath: setPoint]))
  }
  
  func `set`(relay relayTopic: String, to state: Relay.State, qos: MQTTQoS = .atLeastOnce) -> EventLoopFuture<Void> {
    publish(
      to: relayTopic,
      payload: ByteBufferAllocator().buffer(string: state.rawValue),
      qos: qos
    )
  }
}

extension Result where Success == MQTTPublishInfo, Failure == Error {
  
  func mapBuffer<S>(to type: S.Type) -> Result<S?, Error> where S: BufferInitalizable {
    map { info in
      var buffer = info.payload
      return S.init(buffer: &buffer)
    }
  }
}

extension Result {
  
  func fullfill(promise: EventLoopPromise<Success>) {
    switch self {
    case let.success(value):
      promise.succeed(value)
    case let .failure(error):
      promise.fail(error)
    }
  }
  
}

extension Result where Failure == Error {
  
  func unwrap<S, F>(
    or error: @autoclosure @escaping () -> F
  ) -> Result<S, Error> where Success == Optional<S>, Failure == F {
    flatMap { optionalResult in
      guard let value = optionalResult else {
        return .failure(error())
      }
      return .success(value)
    }
  }
}

extension Temperature {
  
  func convert(to units: PsychrometricEnvironment.Units) -> Self {
    let temperatureUnits = Units.defaultFor(units: units)
    return .init(self[temperatureUnits], units: temperatureUnits)
  }
}

extension EventLoopFuture where Value == Temperature {
  
  func convertIfNeeded(to units: PsychrometricEnvironment.Units?) -> EventLoopFuture<Temperature> {
    map { currentTemperature in
      guard let units = units else { return currentTemperature }
      return currentTemperature.convert(to: units)
    }
  }
}

extension EventLoopFuture {
  
  func debug(logger: Logger?) -> EventLoopFuture<Value> {
    map { value in
      logger?.debug("Value: \(value)")
      return value
    }
  }
}
