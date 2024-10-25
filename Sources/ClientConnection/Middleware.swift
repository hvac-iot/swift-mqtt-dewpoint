import Foundation
import Logging

/// `Middleware` is placed between the server. It is capable of  mutating both
/// the incoming requests and outgoing responses. `Middleware` can choose to
/// pass requests on to the next `Middleware` in the chain, or they can short circuit
/// and return a custom ``Response`` if desired.
public protocol Middleware {
  func respond(to request: Request, chainingTo next: Responder) async throws -> Response
}

extension Application {
  public var middleware: Middlewares {
    get {
      if let existing = storage[MiddlewaresKey.self] {
        return existing
      } else {
        let new = Middlewares([
          RouteLoggingMiddleware(logLevel: .info),
          ErrorHandlingMiddleware { request, error in
            let message = """
              Request failed: \(request)
              \(error)
              """
            self.logger.warning("\(message)")
            return .failed(message)
          }
        ])
        storage[MiddlewaresKey.self] = new
        return new
      }
    }
    set {
      storage[MiddlewaresKey.self] = newValue
    }
  }
  
  private struct MiddlewaresKey: StorageKey {
    typealias Value = Middlewares
  }
        
  public struct Middlewares {
    private var storage: [Middleware]
    
    public init() {
      self.storage = []
    }
    
    internal init(_ middlewares: [Middleware]) {
      self.storage = middlewares
    }
    
    public mutating func use(_ middleware: Middleware) {
      self.storage.append(middleware)
    }
    
    public func value() -> [Middleware] {
      self.storage
    }
  }
}

extension Array where Element == Middleware {
  
  public func makeResponder(chainingTo responder: Responder) -> Responder {
    var responder = responder
    for middleware in reversed() {
      responder = middleware.makeResponder(chainingTo: responder)
    }
    return responder
  }
  
}

extension Middleware {
  public func makeResponder(chainingTo responder: Responder) -> Responder {
    DefaultResponder(middleware: self, responder: responder)
  }
}

private struct DefaultResponder: Responder {

  let middleware: Middleware
  let responder: Responder

  func respond(to request: Request) async throws -> Response {
    try await self.middleware.respond(to: request, chainingTo: responder)
  }
}

public struct ErrorHandlingMiddleware: Middleware {
  
  let closure: (Request, Error) async -> Response
  
  public init(_ closure: @escaping (Request, Error) async -> Response) {
    self.closure = closure
  }
  
  public func respond(to request: Request, chainingTo next: Responder) async throws -> Response {
    do {
      return try await next.respond(to: request)
    } catch {
      return await closure(request, error)
    }
  }
}

public struct RouteLoggingMiddleware: Middleware {
  let logLevel: Logger.Level
  
  public init(logLevel: Logger.Level = .info) {
    self.logLevel = logLevel
  }
  
  public func respond(to request: Request, chainingTo next: Responder) async throws -> Response {
    request.logger.log(level: logLevel, "\(request.topic)")
    return try await next.respond(to: request)
  }
}

public struct TopicFilterMiddleware: Middleware {
  let topic: String
  
  public init(_ topic: String) {
    self.topic = topic
  }
  
  public func respond(to request: Request, chainingTo next: Responder) async throws -> Response {
    guard request.topic == self.topic else {
      let message = """
      Topic does not match
      
      requested topic: \(request.topic)
      should match: \(topic)
      """
      return .failed(message)
    }
    return try await next.respond(to: request)
  }
}
