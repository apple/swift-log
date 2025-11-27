// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Benchmarks",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/ordo-one/package-benchmark.git", from: "1.29.6"),
        .package(path: "NoTraits_Benchmarks"),
        .package(path: "DisableTraceLogs_Benchmarks"),
        .package(path: "DisableDebugLogs_Benchmarks"),
        .package(path: "DisableInfoLogs_Benchmarks"),
        .package(path: "DisableNoticeLogs_Benchmarks"),
        .package(path: "DisableWarningLogs_Benchmarks"),
        .package(path: "DisableErrorLogs_Benchmarks"),
        .package(path: "DisableCriticalLogs_Benchmarks"),
    ]
)

package.targets += [
    .executableTarget(
        name: "Benchmarks",
        dependencies: [
            .product(name: "Benchmark", package: "package-benchmark"),
            .product(name: "NoTraits_Benchmarks", package: "NoTraits_Benchmarks"),
            .product(name: "DisableTraceLogs_Benchmarks", package: "DisableTraceLogs_Benchmarks"),
            .product(name: "DisableDebugLogs_Benchmarks", package: "DisableDebugLogs_Benchmarks"),
            .product(name: "DisableInfoLogs_Benchmarks", package: "DisableInfoLogs_Benchmarks"),
            .product(name: "DisableNoticeLogs_Benchmarks", package: "DisableNoticeLogs_Benchmarks"),
            .product(name: "DisableWarningLogs_Benchmarks", package: "DisableWarningLogs_Benchmarks"),
            .product(name: "DisableErrorLogs_Benchmarks", package: "DisableErrorLogs_Benchmarks"),
            .product(name: "DisableCriticalLogs_Benchmarks", package: "DisableCriticalLogs_Benchmarks"),
        ],
        path: "Benchmarks",
        plugins: [
            .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
        ]
    )
]
