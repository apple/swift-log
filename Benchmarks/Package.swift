// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BenchmarksFactory",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "BenchmarksFactory", targets: ["BenchmarksFactory"])
    ],
    dependencies: [
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.29.6"),
        .package(path: "../"),  // swift-log
    ],
    targets: [
        .target(
            name: "BenchmarksFactory",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "Logging", package: "swift-log"),
            ]
        )
    ]
)
