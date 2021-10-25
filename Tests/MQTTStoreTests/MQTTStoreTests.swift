import Logging
import XCTest
import MQTTNIO
@testable import MQTTStore
import NIO

final class ServerTests: XCTestCase {
  
  func testConnect() throws {
    let store = createTestStore()
    _ = try store.connect(cleanSession: true).wait()
    try store.destroy().wait()
  }
  
  func testSubscriptionHandler() throws {
    let store = createTestStore()
    _ = try store.connectAndSubscribe(cleanSession: true).wait()
    
    _ = try store.client?.publish(
      to: "test/topic",
      payload: ByteBufferAllocator().buffer(string: "test"),
      qos: .atLeastOnce
    ).wait()
    
    Thread.sleep(forTimeInterval: 2)
    
    XCTAssertEqual(store.state.messages.count, 1)
    XCTAssertEqual(store.state.messages[0], "test")
    try store.destroy().wait()
  }
  
  
  func createTestStore() -> MQTTStore<TestState> {
    .init(
      state: .init(messages: []),
      subscriptions: [("test/topic", stateHandler(_:_:))],
      serverDetails: serverDetails,
      eventLoopGroup: MultiThreadedEventLoopGroup.init(numberOfThreads: 1),
      logger: logger
    )
  }
  
  let logger: Logger = {
    var logger = Logger(label: "MQTT Test")
    logger.logLevel = .trace
    return logger
  }()
  
  var serverDetails: ServerDetails {
    .init(
      identifier: "Test Server",
      hostname: "localhost",
      port: 1883,
      version: .v3_1_1,
      cleanSession: true,
      useTLS: false,
      useWebSocket: false,
      webSocketUrl: "/mqtt",
      username: nil,
      password: nil
    )
  }
  
  struct TestState {
    var messages: [String]
  }
  
  func stateHandler(_ state: inout TestState, _ result: Result<MQTTPublishInfo, Error>) {
    switch result {
    case let .success(value):
      let payload = String(buffer: value.payload)
      state.messages.append(payload)
    case .failure:
      break
    }
  }
}
