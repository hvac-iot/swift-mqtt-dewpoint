import Foundation
import NIO

public final class Response {
  
  public var status: Status
  public var message: String?
  
  public init(
    status: Status = .success,
    message: String? = nil
  ) {
    self.status = status
    self.message = message
  }
  
  public enum Status {
    case failed
    case publish(ByteBuffer)
    case success
  }
}
