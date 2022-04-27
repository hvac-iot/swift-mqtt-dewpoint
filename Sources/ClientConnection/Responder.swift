import Foundation

public protocol Responder {
 
  func respond(to request: Request) async throws -> Response
}
