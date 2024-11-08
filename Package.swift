// swift-tools-version:5.10

import PackageDescription

let package = Package(
  name: "dewPoint-controller",
  platforms: [
    .macOS(.v12)
  ],
  products: [
    .executable(name: "dewPoint-controller", targets: ["dewPoint-controller"]),
    .library(name: "Bootstrap", targets: ["Bootstrap"]),
    .library(name: "DewPointEnvironment", targets: ["DewPointEnvironment"]),
    .library(name: "EnvVars", targets: ["EnvVars"]),
    .library(name: "Models", targets: ["Models"]),
    .library(name: "Client", targets: ["Client"]),
    .library(name: "ClientLive", targets: ["ClientLive"]),
  ],
  dependencies: [
    .package(url: "https://github.com/swift-server-community/mqtt-nio.git", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-nio", from: "2.0.0"),
    .package(url: "https://github.com/swift-psychrometrics/swift-psychrometrics", from: "0.1.0")
  ],
  targets: [
    .executableTarget(
      name: "dewPoint-controller",
      dependencies: [
        "Bootstrap",
        "ClientLive",
        "TopicsLive",
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
        .product(name: "Psychrometrics", package: "swift-psychrometrics"),
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
        "EnvVars",
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
      name: "TopicsLive",
      dependencies: [
        "Models"
      ]
    ),
  ]
)
