// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "logging",
    products: [
        .library(name: "Logging", targets: ["Logging"]),
    ],
    targets: [
        .target(
            name: "Logging",
            dependencies: []
        ),
        .target(
            name: "ExampleImplementation",
            dependencies: ["Logging"]
        ),
        .target(
            name: "ExampleUsage",
            dependencies: ["Logging", "ExampleImplementation"]
        ),
        .testTarget(
            name: "LoggingTests",
            dependencies: ["Logging"]
        ),
    ]
)
