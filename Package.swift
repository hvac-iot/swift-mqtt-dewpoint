// swift-tools-version:5.10

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableExperimentalFeature("StrictConcurrency")
]

let package = Package(
  name: "dewPoint-controller",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "dewPoint-controller", targets: ["dewPoint-controller"]),
    .library(name: "Bootstrap", targets: ["Bootstrap"]),
    .library(name: "DewPointEnvironment", targets: ["DewPointEnvironment"]),
    .library(name: "EnvVars", targets: ["EnvVars"]),
    .library(name: "Models", targets: ["Models"]),
    .library(name: "Client", targets: ["Client"]),
    .library(name: "ClientLive", targets: ["ClientLive"]),
    .library(name: "SensorsService", targets: ["SensorsService"])
  ],
  dependencies: [
    .package(url: "https://github.com/swift-server-community/mqtt-nio.git", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-nio", from: "2.0.0"),
    .package(url: "https://github.com/swift-psychrometrics/swift-psychrometrics", exact: "0.1.0"),
    .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.3.0")
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
      ],
      swiftSettings: swiftSettings
    ),
    .target(
      name: "DewPointEnvironment",
      dependencies: [
        "EnvVars",
        "Client",
        "Models",
        .product(name: "MQTTNIO", package: "mqtt-nio")
      ],
      swiftSettings: swiftSettings
    ),
    .target(
      name: "EnvVars",
      dependencies: [],
      swiftSettings: swiftSettings
    ),
    .target(
      name: "Models",
      dependencies: [
        .product(name: "Psychrometrics", package: "swift-psychrometrics")
      ],
      swiftSettings: swiftSettings
    ),
    .target(
      name: "Client",
      dependencies: [
        "Models",
        .product(name: "CoreUnitTypes", package: "swift-psychrometrics"),
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "Psychrometrics", package: "swift-psychrometrics")
      ],
      swiftSettings: swiftSettings
    ),
    .target(
      name: "ClientLive",
      dependencies: [
        "Client",
        "EnvVars",
        .product(name: "MQTTNIO", package: "mqtt-nio"),
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle")
      ],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "ClientTests",
      dependencies: [
        "Client",
        "ClientLive"
      ]
    ),
    .target(
      name: "MQTTConnectionService",
      dependencies: [
        "EnvVars",
        .product(name: "MQTTNIO", package: "mqtt-nio"),
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle")
      ],
      swiftSettings: swiftSettings
    ),
    .target(
      name: "SensorsService",
      dependencies: [
        "Models",
        .product(name: "MQTTNIO", package: "mqtt-nio"),
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle")
      ],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "SensorsServiceTests",
      dependencies: [
        "SensorsService",
        // TODO: Remove.
        "ClientLive"
      ]
    ),
    .target(
      name: "TopicsLive",
      dependencies: [
        "Models"
      ],
      swiftSettings: swiftSettings
    )
  ]
)
