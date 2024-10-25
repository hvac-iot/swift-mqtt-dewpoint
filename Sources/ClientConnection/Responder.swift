import Foundation

public protocol Responder {
 
  func respond(to request: Request) async throws -> Response
}

extension Application {
  public var responder: Responder {
    .init(application: self)
  }
  
  public struct Responder {
    public struct Provider {
      public static var `default`: Self {
        .init {
          $0.responder.use { $0.responder.default }
        }
      }
      
      let run: (Application) -> ()
      
      public init(_ run: @escaping (Application) -> ()) {
        self.run = run
      }
    }
    
    final class Storage {
      var factory: ((Application) -> ClientConnection.Responder)?
      init() { }
    }
    
    struct Key: StorageKey {
      typealias Value = Storage
    }
    
    public let application: Application
    
    public var current: ClientConnection.Responder {
      guard let factory = self.storage.factory else {
        fatalError("No responder configured. Configure with app.responder.use(...)")
      }
      return factory(self.application)
    }
    
    public var `default`: ClientConnection.Responder {
      _DefaultApplicationResponder(
        listeners: self.application.listeners.value(),
        middleware: self.application.middleware.value()
      )
    }
    
    public func use(_ provider: Provider) {
      provider.run(self.application)
    }
    
    public func use(_ factory: @escaping (Application) -> (ClientConnection.Responder)) {
      self.storage.factory = factory
    }
    
    var storage: Storage {
      guard let storage = self.application.storage[Key.self] else {
        fatalError("Responder not configured. Configure with app.responder.initialize()")
      }
      return storage
    }
    
    func initialize() {
      self.application.storage[Key.self] = .init()
    }
  }
}

extension Application.Responder: Responder {
  public func respond(to request: Request) async throws -> Response {
    try await self.current.respond(to: request)
  }
  
//  public func respond(to request: Request) -> EventLoopFuture<Response> {
//    self.current.respond(to: request)
//  }
}

extension Application {
  
  
//  public struct Responder {
//    var factory: (Application) -> ApplicationResponder
//
//    static var `default`: Self {
//      .init(factory: DefaultApplicationResponder.init(application:))
//    }
//
//    public mutating func use(_ factory: @escaping (Application) -> ApplicationResponder) {
//      self.factory = factory
//    }
//  }
//
//  public var responder: ApplicationResponder {
//    get {
//      if let existing = storage[ResponderKey.self] {
//        return existing
//      } else {
//        let new = Responder.default
//        storage[ResponderKey.self] = new
//        return new
//      }
//    }
//    set {
//      storage[ResponderKey.self] = newValue
//    }
//  }
  
}

//extension Application {
//
//  public struct Responder {
//
//  }
//}

fileprivate struct _DefaultApplicationResponder: Responder {

  private let cachedListeners: [CachedListener]
  private let notFoundResponder: Responder

  struct CachedListener {
    let listener: Listener
    let responder: Responder
  }

  init(listeners: [Listener], middleware: [Middleware] = []) {
    self.cachedListeners = listeners.map { listener in
      CachedListener(
        listener: listener,
        responder: middleware.makeResponder(chainingTo: listener.responder))
    }
    self.notFoundResponder = NotFoundResponder()
  }

  func respond(to request: Request) async throws -> Response {
    guard let cached = getResponder(for: request) else {
      return try await notFoundResponder.respond(to: request)
    }

    let response = try await cached.responder.respond(to: request)
    switch response.status {
    case let .publish(buffer, topic):
      await request.application.publish(buffer, to: topic)
    case .failed, .success:
      break
    }
    return response
  }

  func getResponder(for request: Request) -> CachedListener? {
    cachedListeners.first(where: { $0.listener.topic == request.topic })
  }
}

struct NotFoundResponder: Responder {
  func respond(to request: Request) async throws -> Response {
    throw NotFoundError()
  }
}

struct NotFoundError: Error { }

