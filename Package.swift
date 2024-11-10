// swift-tools-version:5.10

import PackageDescription

let swiftSettings: [SwiftSetting] = [
  .enableExperimentalFeature("StrictConcurrency"),
  .enableUpcomingFeature("InferSendableCaptures")
]

let package = Package(
  name: "dewPoint-controller",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "dewPoint-controller", targets: ["dewPoint-controller"]),
    .library(name: "Bootstrap", targets: ["Bootstrap"]),
    .library(name: "Models", targets: ["Models"]),
    .library(name: "MQTTConnectionService", targets: ["MQTTConnectionService"]),
    .library(name: "SensorsService", targets: ["SensorsService"])
  ],
  dependencies: [
    .package(url: "https://github.com/swift-server-community/mqtt-nio.git", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-nio", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
    .package(url: "https://github.com/swift-psychrometrics/swift-psychrometrics", exact: "0.2.3"),
    .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.3.0")
  ],
  targets: [
    .executableTarget(
      name: "dewPoint-controller",
      dependencies: [
        "Models",
        "MQTTConnectionService",
        "SensorsService",
        .product(name: "MQTTNIO", package: "mqtt-nio"),
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "PsychrometricClientLive", package: "swift-psychrometrics")
      ]
    ),
    .testTarget(
      name: "dewPoint-controllerTests",
      dependencies: ["dewPoint-controller"]
    ),
    .target(
      name: "Bootstrap",
      dependencies: [
        "Models",
        .product(name: "MQTTNIO", package: "mqtt-nio"),
        .product(name: "NIO", package: "swift-nio")
      ],
      swiftSettings: swiftSettings
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
      name: "MQTTConnectionService",
      dependencies: [
        "Models",
        .product(name: "MQTTNIO", package: "mqtt-nio"),
        .product(name: "ServiceLifecycle", package: "swift-service-lifecycle")
      ],
      swiftSettings: swiftSettings
    ),
    .testTarget(
      name: "MQTTConnectionServiceTests",
      dependencies: [
        "MQTTConnectionService",
        .product(name: "ServiceLifecycleTestKit", package: "swift-service-lifecycle")
      ]
    ),
    .target(
      name: "SensorsService",
      dependencies: [
        "Models",
        "MQTTConnectionService",
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
    )
  ]
)
