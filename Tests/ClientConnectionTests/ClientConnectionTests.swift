import XCTest
import EnvVars
import Models
import MQTTNIO
import NIO
import Psychrometrics
@testable import ClientConnection

final class ClientConnectionTests: XCTestCase {
  static let hostname = ProcessInfo.processInfo.environment["MOSQUITTO_SERVER"] ?? "localhost"
  
  func createEnvVars(identifier: String) -> EnvVars {
    .init(
      appEnv: .testing,
      host: Self.hostname,
      port: "1883",
      identifier: identifier,
      userName: nil,
      password: nil
    )
  }
  
  func createConnection(identifier: String) -> MQTTClientConnection {
    return .init(envVars: createEnvVars(identifier: identifier))
  }
  
  func createManager(identifier: String) -> MQTTConnectionManager {
    .init(envVars: createEnvVars(identifier: identifier))
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
 
//  func testListenerStream() async {
//    let expectation = XCTestExpectation(description: "testListenerStream")
//    expectation.expectedFulfillmentCount = 1
//    let finishExpectation = XCTestExpectation(description: "testListenerStream.finish")
//    finishExpectation.expectedFulfillmentCount = 1
//
//    let conn1 = createConnection(identifier: "testListenerStream-1")
//    let conn2 = createConnection(identifier: "testListenerStream-2")
//
//    let payloadString = "foo"
//    let offTopicString = "test/testListenerStream/offTopic"
//    let topicString = "test/testListenerStream"
//
//    struct TestListenerTopic: MQTTTopicListener, MQTTTopicSubscriber, MQTTTopicPublisher {
//
//      var topic: String
//
//      var subscriberInfo: MQTTClientConnection.SubscriberInfo {
//        .init(topic: topic, properties: .init(), qos: .atLeastOnce)
//      }
//
//      var publisherInfo: MQTTClientConnection.PublisherInfo {
//        .init(topic: topic, qos: .atLeastOnce, retain: false)
//      }
//    }
//
//    let offTopic = MQTTClientConnection.PublisherInfo(topic: offTopicString)
//
//    self.XCTRunAsyncAndBlock {
//      await conn1.connect()
//      await conn2.connect()
//
//      let onTopic = TestListenerTopic(topic: topicString)
//
//      await onTopic.subscribe(connection: conn2)
//
//      let task = Task {
//        let stream = onTopic
//          .topicStream(connection: conn2)
//          .map { String.init(buffer: $0.payload) }
//
//        for await string in stream {
//          XCTAssertEqual(string, payloadString)
//          expectation.fulfill()
//        }
//        finishExpectation.fulfill()
//      }
//
//      // ensure the stream is filtered by the topic, so we should not recieve the off topic.
//      _ = await offTopic.publish(payload: payloadString, on: conn1)
//      _ = await onTopic.publish(payload: payloadString, on: conn1)
//      // ensure the stream is filtered by the topic, so we should not recieve the off topic.
//      _ = await offTopic.publish(payload: payloadString, on: conn1)
//
//      await conn1.shutdown()
//
//      self.wait(for: [expectation], timeout: 5)
//
//      await conn2.shutdown()
//
//      self.wait(for: [finishExpectation], timeout: 5)
//
//      _ = await task.value
//    }
//  }
//
//  func testConnectionManager() async {
//    let expectation = XCTestExpectation(description: "testConnectionManager")
//    expectation.expectedFulfillmentCount = 1
//
//    let topicString = "test/connectionManager"
//    let outboundTopicString = "test/connectionManager/publisher"
//    let payloadString = "73.1"
//
//    let manager = createManager(identifier: "testConnectionManager.publisher")
//    let manager2 = createManager(identifier: "testConnectionManager.listener")
//
//    let onTopic = TestTopic(topic: topicString)
//    let outboundTopic = TestTopic(topic: outboundTopicString)
//
//    manager.registerSubscribers(onTopic)
//    manager.registerPublishers(outboundTopic)
//    manager.registerListeners(
//      MQTTConnectionManager.Listener(topic: topicString, handler: { (manager, payload) in
//        await manager.publish(payload.payload, to: outboundTopicString)
//      })
//    )
//
//    manager2.registerSubscribers(outboundTopic)
//    manager2.registerListeners(
//      MQTTConnectionManager.Listener(topic: outboundTopicString, handler: { (_, payload) in
//        let string = String(buffer: payload.payload)
//        XCTAssertEqual(string, payloadString)
//        expectation.fulfill()
//      })
//    )
//
//    let conn = createConnection(identifier: "testConnectionManager.connection")
//
//    self.XCTRunAsyncAndBlock {
//      await manager.start()
//      await manager2.start()
//
//      await conn.connect()
//      _ = try! await conn.client.publish(to: topicString, payload: payloadString.buffer, qos: .atLeastOnce)
//      await conn.shutdown()
//
//      self.wait(for: [expectation], timeout: 5)
//
//      await manager.stop()
//      await manager2.stop()
//    }
//  }
  
  func testApplication() async {
    let expectation = XCTestExpectation(description: "testApplication")
    expectation.expectedFulfillmentCount = 1
    
    let app = Application(createEnvVars(identifier: "testApplication"))
    
//    var storage: String? = nil
    let topicString = "test/testApplication/1"
    let topicTwo = "test/testApplication/2"
    let payloadString = "foo"
    
//    app.middleware.use(TopicFilterMiddleware(topicString))
    
    app.listeners.use(BasicListener.init(topic: topicString, responder: { request in
      let string = String(buffer: request.body.payload)
      XCTAssertEqual(string, payloadString)
      expectation.fulfill()
      return .success
//      for await payload in stream {
//        let string = String(buffer: payload.payload)
//        XCTAssertEqual(string, payloadString)
//        expectation.fulfill()
//      }
    }))
    app.listeners.use(BasicListener.init(topic: topicTwo, responder: { _ in
      XCTFail("Should not recieve values on topic two.")
      return .failed()
    }))
    
    app.publishers.use(TestTopic(topic: topicString))
    
//    let conn = createConnection(identifier: "testApplication.connection")
    
    self.XCTRunAsyncAndBlock {
      try! await app.start()
      
      try! await Task.sleep(nanoseconds: 1_000_000_000)
      
      await app.publish(payloadString, to: topicString)
      
//      await conn.connect()
//      _ = try! await conn.client.publish(to: topicString, payload: payloadString.buffer, qos: .atLeastOnce)
//      await conn.shutdown()
      
      self.wait(for: [expectation], timeout: 5)
      
      await app.shutdown()
    }
  }
}

extension String: BufferRepresentable {
 
  public var buffer: ByteBuffer { ByteBufferAllocator().buffer(string: self) }
}

extension String: BufferInitalizable { }

struct TestTopic: MQTTTopicSubscriber, MQTTTopicPublisher, MQTTTopicListener {
  
  let topic: String
  
  var subscriberInfo: MQTTClientConnection.SubscriberInfo {
    .init(topic: topic, properties: .init(), qos: .atLeastOnce)
  }
  
  var publisherInfo: MQTTClientConnection.PublisherInfo {
    .init(topic: topic, qos: .atLeastOnce, retain: false)
  }
}

struct  TemperatureHumiditySensor {
  var temperature: Temperature?
  var humidity: RelativeHumidity?
  var topic: String
  
//  func publish(on application: Application) async {
//    
//  }
}
