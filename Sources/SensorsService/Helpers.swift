import CoreUnitTypes
import Logging
import Models
import MQTTNIO
import NIO
import NIOFoundationCompat
import Psychrometrics

/// Represents a type that can be initialized by a ``ByteBuffer``.
protocol BufferInitalizable {
  init?(buffer: inout ByteBuffer)
}

extension Double: BufferInitalizable {

  /// Attempt to create / parse a double from a byte buffer.
  init?(buffer: inout ByteBuffer) {
    guard let string = buffer.readString(
      length: buffer.readableBytes,
      encoding: String.Encoding.utf8
    )
    else { return nil }
    self.init(string)
  }
}

extension Temperature: BufferInitalizable {
  /// Attempt to create / parse a temperature from a byte buffer.
  init?(buffer: inout ByteBuffer) {
    guard let value = Double(buffer: &buffer) else { return nil }
    self.init(value, units: .celsius)
  }
}

extension RelativeHumidity: BufferInitalizable {
  /// Attempt to create / parse a relative humidity from a byte buffer.
  init?(buffer: inout ByteBuffer) {
    guard let value = Double(buffer: &buffer) else { return nil }
    self.init(value)
  }
}
