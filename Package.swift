// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Puck",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0")
    ],
    targets: [
        // Core functionality module
        .target(
            name: "PuckCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/PuckCore"
        ),
        // CLI module
        .executableTarget(
            name: "Puck",
            dependencies: [
                "PuckCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/Puck",
            resources: [
                .copy("com.puck.daemon.plist")
            ]
        ),
        // Tests
        .testTarget(
            name: "PuckCoreTests",
            dependencies: ["PuckCore"],
            path: "Tests/PuckCoreTests"
        ),
        .testTarget(
            name: "PuckTests",
            dependencies: ["Puck"],
            path: "Tests/PuckTests"
        )
    ]
)
