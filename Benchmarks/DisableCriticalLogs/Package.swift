// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DisableCriticalLogs",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DisableCriticalLogs", targets: ["DisableCriticalLogs"])
    ],
    dependencies: [
        // swift-log
        .package(
            path: "../../",
            traits: ["DisableCriticalLogs"]
        ),
        // Parent Benchmarks
        .package(name: "Benchmarks", path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.29.6"),
    ],
    targets: [
        .executableTarget(
            name: "DisableCriticalLogs",
            dependencies: [
                .product(name: "BenchmarksFactory", package: "Benchmarks"),
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
