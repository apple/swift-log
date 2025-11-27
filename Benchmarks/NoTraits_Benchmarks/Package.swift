// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NoTraits_Benchmarks",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "NoTraits_Benchmarks", targets: ["NoTraits_Benchmarks"])
    ],
    dependencies: [
        // swift-log
        .package(
            path: "../../"
        ),
        // BenchmarkingUtils
        .package(path: "../BenchmarkingUtils"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.29.6"),
    ],
    targets: [
        .target(
            name: "NoTraits_Benchmarks",
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
