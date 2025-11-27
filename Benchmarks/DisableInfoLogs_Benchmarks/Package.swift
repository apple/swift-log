// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DisableInfoLogs_Benchmarks",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "DisableInfoLogs_Benchmarks", targets: ["DisableInfoLogs_Benchmarks"])
    ],
    dependencies: [
        // swift-log
        .package(
            path: "../../",
            traits: ["DisableInfoLogs"]
        ),
        // BenchmarkingUtils
        .package(path: "../BenchmarkingUtils"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.29.6"),
    ],
    targets: [
        .target(
            name: "DisableInfoLogs_Benchmarks",
            dependencies: [
                .product(name: "BenchmarkingUtils", package: "BenchmarkingUtils"),
                .product(name: "Benchmark", package: "package-benchmark"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Benchmarks",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    ]
)
