import Foundation
import NIO
import Models

public final class Response {
  
  public var status: Status
  public var message: String?
  
  init(
    status: Status = .success,
    message: String? = nil
  ) {
    self.status = status
    self.message = message
  }
  
  public enum Status {
    case failed
    case publish(ByteBuffer, String)
    case success
  }
  
  public static func publish(_ buffer: ByteBuffer, to topic: String) -> Self {
    self.init(status: .publish(buffer, topic), message: nil)
  }
  
  public static func publish(_ buffer: BufferRepresentable, to topic: String) -> Self {
    .publish(buffer.buffer, to: topic)
  }
  
  public static var success: Self { .init() }
  
  public static func failed(_ message: String? = nil) -> Self {
    return .init(status: .failed, message: message)
  }
}
