import Foundation
import Models
import NIO

public struct RelayClient {
  public var toggle: (Relay) -> EventLoopFuture<Void>
  public var turnOn: (Relay) -> EventLoopFuture<Void>
  public var turnOff: (Relay) -> EventLoopFuture<Void>
  
  public init(
    toggle: @escaping (Relay) -> EventLoopFuture<Void>,
    turnOn: @escaping (Relay) -> EventLoopFuture<Void>,
    turnOff: @escaping (Relay) -> EventLoopFuture<Void>
  ) {
    self.toggle = toggle
    self.turnOn = turnOn
    self.turnOff = turnOff
  }
}

