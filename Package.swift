// swift-tools-version:5.5

import PackageDescription

let package = Package(
  name: "dewPoint-controller",
  platforms: [
    .macOS(.v10_14)
  ],
  products: [
    .executable(name: "dewPoint-controller", targets: ["dewPoint-controller"]),
    .library(name: "Bootstrap", targets: ["Bootstrap"]),
    .library(name: "DewPointEnvironment", targets: ["DewPointEnvironment"]),
    .library(name: "EnvVars", targets: ["EnvVars"]),
    .library(name: "Models", targets: ["Models"]),
    .library(name: "RelayClient", targets: ["RelayClient"]),
    .library(name: "TemperatureSensorClient", targets: ["TemperatureSensorClient"]),
  ],
  dependencies: [
    .package(url: "https://github.com/adam-fowler/mqtt-nio.git", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-nio", from: "2.0.0"),
    .package(url: "https://github.com/swift-psychrometrics/swift-psychrometrics", from: "0.1.0")
  ],
  targets: [
    .executableTarget(
      name: "dewPoint-controller",
      dependencies: [
        "Bootstrap",
        .product(name: "MQTTNIO", package: "mqtt-nio"),
        .product(name: "NIO", package: "swift-nio")
      ]
    ),
    .testTarget(
      name: "dewPoint-controllerTests",
      dependencies: ["dewPoint-controller"]
    ),
    .target(
      name: "Bootstrap",
      dependencies: [
        "DewPointEnvironment",
        "EnvVars",
        "RelayClient",
        "TemperatureSensorClient",
        .product(name: "MQTTNIO", package: "mqtt-nio"),
        .product(name: "NIO", package: "swift-nio")
      ]
    ),
    .target(
      name: "DewPointEnvironment",
      dependencies: [
        "EnvVars",
        "RelayClient",
        "TemperatureSensorClient",
        .product(name: "MQTTNIO", package: "mqtt-nio"),
      ]
    ),
    .target(
      name: "EnvVars",
      dependencies: []
    ),
    .target(
      name: "Models",
      dependencies: []
    ),
    .target(
      name: "RelayClient",
      dependencies: [
        "Models",
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "MQTTNIO", package: "mqtt-nio")
      ]
    ),
    .target(
      name: "TemperatureSensorClient",
      dependencies: [
        "Models",
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "MQTTNIO", package: "mqtt-nio"),
        .product(name: "CoreUnitTypes", package: "swift-psychrometrics")
      ]
    ),
  ]
)
