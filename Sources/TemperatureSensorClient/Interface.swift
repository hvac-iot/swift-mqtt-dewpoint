import Foundation
import CoreUnitTypes
import Models
import NIO

public struct TemperatureSensorClient {
  public var state: (TemperatureSensor, PsychrometricEnvironment.Units?) -> EventLoopFuture<Temperature>
  
  public init(
    state: @escaping (TemperatureSensor, PsychrometricEnvironment.Units?) -> EventLoopFuture<Temperature>
  ) {
    self.state = state
  }
}
