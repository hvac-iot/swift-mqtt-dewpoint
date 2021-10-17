import Foundation

/// Holds common settings for connecting to your MQTT broker.  The default values can be used,
/// they can be loaded from the shell environment, or from a file located in the root directory.
///
/// This allows us to keep sensitve settings out of the repository.
public struct EnvVars: Codable, Equatable {
  
  /// The current app environment.
  public var appEnv: AppEnv
  
  /// The MQTT host.
  public var host: String
  
  /// The MQTT port.
  public var port: String?
  
  /// The identifier to use when connecting to the MQTT broker.
  public var identifier: String
  
  /// The MQTT user name.
  public var userName: String?
  
  /// The MQTT user password.
  public var password: String?
  
  /// Create a new ``EnvVars``
  ///
  /// - Parameters:
  ///   - appEnv: The current application environment
  ///   - host: The MQTT host.
  ///   - port: The MQTT port.
  ///   - identifier: The identifier to use when connecting to the MQTT broker.
  ///   - userName: The MQTT user name to connect to the broker with.
  ///   - password: The MQTT user password to connect to the broker with.
  public init(
    appEnv: AppEnv = .development,
    host: String = "127.0.0.1",
    port: String? = "1883",
    identifier: String = "dewPoint-controller",
    userName: String? = "mqtt_user",
    password: String? = "secret!"
  ){
    self.appEnv = appEnv
    self.host = host
    self.port = port
    self.identifier = identifier
    self.userName = userName
    self.password = password
  }
  
  /// Custom coding keys.
  private enum CodingKeys: String, CodingKey {
    case appEnv = "APP_ENV"
    case host = "MQTT_HOST"
    case port = "MQTT_PORT"
    case identifier = "MQTT_IDENTIFIER"
    case userName = "MQTT_USERNAME"
    case password = "MQTT_PASSWORD"
  }
  
  /// Represents the different app environments.
  public enum AppEnv: String, Codable {
    case development
    case production
    case staging
    case testing
  }
}
