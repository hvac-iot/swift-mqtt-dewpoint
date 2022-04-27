import Logging

public struct Storage {
  var storage: [ObjectIdentifier: AnyStorageValue]
  let logger: Logger
  
  public init(logger: Logger = .init(label: "mqttClient.storage")) {
    self.logger = logger
    self.storage = [:]
  }
  
  public subscript<Key>(_ key: Key.Type) -> Key.Value? where Key: StorageKey {
    get { self.get(Key.self) }
    set { self.set(Key.self, to: newValue) }
  }
  
  public mutating func clear() {
    self.storage = [:]
  }
  
  public func contains<Key>(_ key: Key.Type) -> Bool {
    self.storage.keys.contains(ObjectIdentifier(Key.self))
  }
  
  public func get<Key>(_ key: Key.Type) -> Key.Value? where Key: StorageKey {
    guard let value = self.storage[ObjectIdentifier(Key.self)] as? Value<Key.Value> else {
      return nil
    }
    return value.value
  }
  
  public mutating func set<Key>(
    _ key: Key.Type,
    to value: Key.Value?,
    onShutdown: ((Key.Value) throws -> ())? = nil
  ) where Key: StorageKey {
    let key = ObjectIdentifier(Key.self)
    guard let value = value else {
      // if setting to nil, then call shutdown on existing value.
      if let existing = self.storage[key] {
        self.storage[key] = nil
        existing.shutdown(logger: logger)
      }
      return
    }
    // set the value in storage.
    self.storage[key] = Value(value: value, onShutdown: onShutdown)
  }
  
  public func shutdown() {
    self.storage.values.forEach {
      $0.shutdown(logger: logger)
    }
  }
  
  struct Value<T>: AnyStorageValue {
    var value: T
    var onShutdown: ((T) throws -> ())?
    
    func shutdown(logger: Logger) {
      do {
        try self.onShutdown?(value)
      } catch {
        logger.warning("Could not shutdown: \(T.self) error: \(error)")
      }
    }
  }
}

public protocol AnyStorageValue {
  func shutdown(logger: Logger)
}

public protocol StorageKey {
  associatedtype Value
}
