// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MaxLogLevelNone",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MaxLogLevelNone", targets: ["MaxLogLevelNone"])
    ],
    dependencies: [
        // swift-log
        .package(
            path: "../../",
            traits: ["MaxLogLevelNone"]
        ),
        // Parent Benchmarks
        .package(name: "Benchmarks", path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.29.6"),
    ],
    targets: [
        .executableTarget(
            name: "MaxLogLevelNone",
            dependencies: [
                .product(name: "BenchmarksFactory", package: "Benchmarks"),
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Benchmarks/MaxLogLevelNoneBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    ]
)
