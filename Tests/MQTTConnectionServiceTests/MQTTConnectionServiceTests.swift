import Combine
import Logging
import Models
@testable import MQTTConnectionService
import MQTTNIO
import NIO
import ServiceLifecycle
import ServiceLifecycleTestKit
import XCTest

final class MQTTConnectionServiceTests: XCTestCase {

  static let hostname = ProcessInfo.processInfo.environment["MOSQUITTO_SERVER"] ?? "localhost"

  static let logger: Logger = {
    var logger = Logger(label: "AsyncClientTests")
    logger.logLevel = .trace
    return logger
  }()

  func testGracefulShutdownWorks() async throws {
    try await testGracefulShutdown { trigger in
      let client = createClient(identifier: "testGracefulShutdown")
      let service = MQTTConnectionService(client: client)
      try await service.run()
      try await Task.sleep(for: .seconds(1))
      XCTAssert(client.isActive())
      trigger.triggerGracefulShutdown()
      // try await Task.sleep(for: .seconds(2))
      // XCTAssertFalse(client.isActive())
    }
  }

  func createClient(identifier: String) -> MQTTClient {
    let envVars = EnvVars(
      appEnv: .testing,
      host: Self.hostname,
      port: "1883",
      identifier: identifier,
      userName: nil,
      password: nil
    )
    let config = MQTTClient.Configuration(
      version: .v3_1_1,
      userName: envVars.userName,
      password: envVars.password,
      useSSL: false,
      useWebSockets: false,
      tlsConfiguration: nil,
      webSocketURLPath: nil
    )
    return .init(
      host: Self.hostname,
      identifier: identifier,
      eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup(numberOfThreads: 1)),
      logger: Self.logger,
      configuration: config
    )
  }

  func testEventStream() async throws {
    var connection: ConnectionStream? = ConnectionStream()

    let task = Task {
      guard let events = connection?.events else { return }
      print("before loop")
      for await event in events {
        print("\(event)")
      }
      print("after loop")
    }

    let ending = Task {
      try await Task.sleep(for: .seconds(2))
      connection = nil
    }

    connection?.start()
    try await ending.value
    task.cancel()
  }

}

class ConnectionStream {

  enum Event {
    case connected
    case disconnected
    case shuttingDown
  }

  let events: AsyncStream<Event>
  private let continuation: AsyncStream<Event>.Continuation
  private var cancellable: AnyCancellable?

  init() {
    let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
    self.events = stream
    self.continuation = continuation
  }

  deinit {
    print("connection stream is gone.")
    stop()
  }

  func start() {
    cancellable = Timer.publish(every: 1.0, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        print("will send event.")
        self?.continuation.yield(.connected)
      }
  }

  func stop() {
    continuation.yield(.shuttingDown)
    cancellable = nil
    continuation.finish()
  }
}
