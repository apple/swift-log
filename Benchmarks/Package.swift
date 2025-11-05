// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.29.6"),
    ]
)

// Benchmark of SwiftLogBenchmarks
package.targets += [
    .executableTarget(
        name: "SwiftLogBenchmarks",
        dependencies: [
            .product(name: "Benchmark", package: "package-benchmark"),
            .product(name: "Logging", package: "swift-log"),
        ],
        path: "Benchmarks/SwiftLogBenchmarks",
        plugins: [
            .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
        ]
    )
]
