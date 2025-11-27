// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BenchmarkingUtils",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "BenchmarkingUtils", targets: ["BenchmarkingUtils"])
    ],
    dependencies: [
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.29.6"),

        // swift-log
        .package(path: "../../"),
    ],
    targets: [
        .target(
            name: "BenchmarkingUtils",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "Logging", package: "swift-log"),
            ]
        )
    ]
)
