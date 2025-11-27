// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Benchmarks", targets: ["Benchmarks"])
    ],
    dependencies: [
        // swift-log
        .package(
            path: "../../"
        ),
        // Parent Benchmarks
        .package(name: "BenchmarksFactory", path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.29.6"),
    ],
    targets: [
        .executableTarget(
            name: "Benchmarks",
            dependencies: [
                .product(name: "BenchmarksFactory", package: "BenchmarksFactory"),
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
