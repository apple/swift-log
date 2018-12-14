// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-server-logging-api-proposal",
    products: [
        .library(name: "Logging", targets: ["Logging"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Logging",
            dependencies: []
        ),
        .target(
            name: "Examples",
            dependencies: ["Logging"]
        ),
        .testTarget(
            name: "LoggingTests",
            dependencies: ["Logging"]
        ),
    ]
)
