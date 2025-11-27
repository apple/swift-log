// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DisableInfoLogs",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DisableInfoLogs", targets: ["DisableInfoLogs"])
    ],
    dependencies: [
        // swift-log
        .package(
            path: "../../",
            traits: ["DisableInfoLogs"]
        ),
        // Parent Benchmarks
        .package(name: "BenchmarksFactory", path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.29.6"),
    ],
    targets: [
        .executableTarget(
            name: "DisableInfoLogs",
            dependencies: [
                .product(name: "BenchmarksFactory", package: "BenchmarksFactory"),
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Benchmarks/DisableInfoLogsBenchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    ]
)
