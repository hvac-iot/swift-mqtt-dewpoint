// swift-tools-version:5.10

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableExperimentalFeature("StrictConcurrency"),
  .enableUpcomingFeature("InferSendableCaptures")
]

let package = Package(
  name: "dewpoint-controller",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "dewpoint-controller", targets: ["dewpoint-controller"]),
    .library(name: "Models", targets: ["Models"]),
    .library(name: "MQTTConnectionManager", targets: ["MQTTConnectionManager"]),
    .library(name: "MQTTConnectionService", targets: ["MQTTConnectionService"]),
    .library(name: "SensorsService", targets: ["SensorsService"]),
    .library(name: "TopicDependencies", targets: ["TopicDependencies"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-nio", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.4.1"),
    .package(url: "https://github.com/swift-psychrometrics/swift-psychrometrics", exact: "0.2.3"),
    .package(url: "https://github.com/swift-server-community/mqtt-nio.git", from: "2.0.0"),
    .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.3.0")
  ],
  targets: [
    .executableTarget(
      name: "dewpoint-controller",
      dependencies: [
        "Models",
        "MQTTConnectionManager",
        "MQTTConnectionService",
        "SensorsService",
        "TopicDependencies",
        .product(name: "MQTTNIO", package: "mqtt-nio"),
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "PsychrometricClientLive", package: "swift-psychrometrics")
      ]
    ),
    .target(
      name: "Models",
      dependencies: [
        .product(name: "Logging", package: "swift-log"),
        .product(name: "PsychrometricClient", package: "swift-psychrometrics")
      ],
      swiftSettings: swiftSettings
    ),
    .target(
      name: "MQTTConnectionManager",
      dependencies: [
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "MQTTNIO", package: "mqtt-nio")
      ],
      swiftSettings: swiftSettings
    ),
    .target(
      name: "MQTTConnectionService",
      dependencies: [
        "Models",
        "MQTTConnectionManager",
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle")
      ],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "MQTTConnectionServiceTests",
      dependencies: [
        "MQTTConnectionService",
        "MQTTConnectionManager",
        .product(name: "ServiceLifecycleTestKit", package: "swift-service-lifecycle")
      ]
    ),
    .target(
      name: "SensorsService",
      dependencies: [
        "Models",
        "MQTTConnectionService",
        "TopicDependencies",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "MQTTNIO", package: "mqtt-nio"),
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle")
      ],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "SensorsServiceTests",
      dependencies: [
        "SensorsService",
        .product(name: "PsychrometricClientLive", package: "swift-psychrometrics")
      ]
    ),
    .target(
      name: "TopicDependencies",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "DependenciesMacros", package: "swift-dependencies"),
        .product(name: "MQTTNIO", package: "mqtt-nio")
      ],
      swiftSettings: swiftSettings
    )
  ]
)
