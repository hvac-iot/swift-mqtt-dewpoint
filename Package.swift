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
    .library(name: "Client", targets: ["Client"]),
    .library(name: "ClientLive", targets: ["ClientLive"]),
    .library(name: "MQTTStore", targets: ["MQTTStore"]),
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
        "ClientLive",
        "Models",
        .product(name: "MQTTNIO", package: "mqtt-nio"),
        .product(name: "NIO", package: "swift-nio")
      ]
    ),
    .target(
      name: "DewPointEnvironment",
      dependencies: [
        "EnvVars",
        "Client",
        "Models",
        .product(name: "MQTTNIO", package: "mqtt-nio"),
      ]
    ),
    .target(
      name: "EnvVars",
      dependencies: []
    ),
    .target(
      name: "Models",
      dependencies: [
        .product(name: "CoreUnitTypes", package: "swift-psychrometrics"),
      ]
    ),
    .target(
      name: "Client",
      dependencies: [
        "Models",
        .product(name: "CoreUnitTypes", package: "swift-psychrometrics"),
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "Psychrometrics", package: "swift-psychrometrics")
      ]
    ),
    .target(
      name: "ClientLive",
      dependencies: [
        "Client",
        .product(name: "MQTTNIO", package: "mqtt-nio")
      ]
    ),
    .testTarget(
      name: "ClientTests",
      dependencies: [
        "Client",
        "ClientLive"
      ]
    ),
    .target(
      name: "MQTTStore",
      dependencies: [
        .product(name: "MQTTNIO", package: "mqtt-nio")
      ]
    ),
    .testTarget(
      name: "MQTTStoreTests",
      dependencies: ["MQTTStore"]
    )
  ]
)
