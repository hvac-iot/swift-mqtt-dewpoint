import XCTest
import EnvVars
import Models
import MQTTNIO
import NIO
@testable import ClientConnection

final class ClientConnectionTests: XCTestCase {
  static let hostname = ProcessInfo.processInfo.environment["MOSQUITTO_SERVER"] ?? "localhost"
  
  func createConnection(identifier: String) -> MQTTClientConnection {
    let envVars = EnvVars.init(
      appEnv: .testing,
      host: Self.hostname,
      port: "1883",
      identifier: identifier,
      userName: nil,
      password: nil
    )
    return .init(envVars: envVars)
  }
  
  func XCTRunAsyncAndBlock(_ closure: @escaping () async -> Void) {
    let dg = DispatchGroup()
    dg.enter()
    Task {
      await closure()
      dg.leave()
    }
    dg.wait()
  }
  
  func testMQTTClientConnection() async {
    let conn = createConnection(identifier: "testMQTTClientConnection")
    await conn.connect()
    await conn.shutdown()
    XCTAssertTrue(conn.shuttingDown)
  }
 
  func testListenerStream() async {
    let expectation = XCTestExpectation(description: "testListenerStream")
    expectation.expectedFulfillmentCount = 1
       
    let conn1 = createConnection(identifier: "testListenerStream-1")
    let conn2 = createConnection(identifier: "testListenerStream-2")
    
    let payloadString = "foo"
    let offTopic = "test/testListenerStream/offTopic"
    let topic = "test/testListenerStream"
    
    struct TestListener: MQTTTopicListener {
      var topic: String
    }
    
    self.XCTRunAsyncAndBlock {
      await conn1.connect()
      await conn2.connect()
      
      await conn2.subscribe(topic: topic)
     
      let task = Task {
        let stream = TestListener(topic: topic)
          .topicStream(connection: conn2)
          .map { String.init(buffer: $0.payload) }
        
        for await string in stream {
          XCTAssertEqual(string, payloadString)
          expectation.fulfill()
        }
      }
     
      // ensure the stream is filtered by the topic, so we should not recieve the off topic.
      _ = await conn1.publish(topic: offTopic, payload: payloadString, retain: false)
      _ = await conn1.publish(topic: topic, payload: payloadString, retain: false)
      // ensure the stream is filtered by the topic, so we should not recieve the off topic.
      _ = await conn1.publish(topic: offTopic, payload: payloadString, retain: false)
       
      await conn1.shutdown()
      
      self.wait(for: [expectation], timeout: 5)
      
      await conn2.shutdown()
     
      _ = await task.value
    }
  }
}

extension String: BufferRepresentable {
 
  public var buffer: ByteBuffer { ByteBufferAllocator().buffer(string: self) }
}

extension String: BufferInitalizable { }
