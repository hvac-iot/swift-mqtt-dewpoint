import Foundation

public struct EnvVars: Codable, Equatable {
  
  public var appEnv: AppEnv
  public var host: String
  public var port: String?
  public var identifier: String
  public var userName: String?
  public var password: String?
  
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
  
  private enum CodingKeys: String, CodingKey {
    case appEnv = "APP_ENV"
    case host = "MQTT_HOST"
    case port = "MQTT_PORT"
    case identifier = "MQTT_IDENTIFIER"
    case userName = "MQTT_USERNAME"
    case password = "MQTT_PASSWORD"
  }
  
  public enum AppEnv: String, Codable {
    case development
    case production
    case staging
    case testing
  }
}
