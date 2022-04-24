import Foundation
import NIO
import Psychrometrics

public protocol BufferRepresentable {
  var buffer: ByteBuffer { get }
}

/// Represents a type that can be initialized by a ``ByteBuffer``.
public protocol BufferInitalizable {
  init?(buffer: ByteBuffer)
}

extension Double: BufferRepresentable, BufferInitalizable {
  
  /// Attempt to create / parse a double from a byte buffer.
  public init?(buffer: ByteBuffer) {
    var buffer = buffer
    guard let string = buffer.readString(length: buffer.readableBytes) else { return nil }
    self.init(string)
  }
  
  public var buffer: ByteBuffer {
    ByteBufferAllocator().buffer(string: "\(self)")
  }
}

extension EnthalpyOf: BufferRepresentable where T == MoistAir {
  public var buffer: ByteBuffer {
    (round(self.rawValue * 100) / 100).buffer
  }
}

extension DewPoint: BufferRepresentable {
  public var buffer: ByteBuffer {
    (round(self.rawValue * 100) / 100).buffer
  }
}

extension Temperature: BufferInitalizable {
  /// Attempt to create / parse a temperature from a byte buffer.
  public init?(buffer: ByteBuffer) {
    guard let value = Double(buffer: buffer) else { return nil }
    self.init(value, units: .celsius)
  }
}

extension RelativeHumidity: BufferInitalizable {
  /// Attempt to create / parse a relative humidity from a byte buffer.
  public init?(buffer: ByteBuffer) {
    guard let value = Double(buffer: buffer) else { return nil }
    self.init(value)
  }
}
