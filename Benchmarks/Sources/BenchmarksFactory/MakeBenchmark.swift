import Benchmark
import Foundation
import Logging

public func makeBenchmark(
    loggerLevel: Logger.Level,
    logLevel: Logger.Level,
    _ suffix: String = "",
    _ body: @escaping (Logger) -> Void
) {
    let iterations = 1_000_000
    let metrics: [BenchmarkMetric] = [.instructions, .objectAllocCount]

    var logger = Logger(label: "BenchmarkRunner_\(loggerLevel)_\(logLevel)")

    // Use a NoOpLogHandler to avoid polluting the logs
    logger.handler = NoOpLogHandler(label: "NoOpLogHandler")
    logger.logLevel = loggerLevel

    Benchmark(
        "\(logLevel)_log_with_\(loggerLevel)_log_level\(suffix)",
        configuration: .init(
            metrics: metrics,
            maxIterations: iterations,
            thresholds: [
                .instructions: BenchmarkThresholds(
                    relative: [
                        .p90: 1.0  // we only record p90
                    ]
                ),
                .objectAllocCount: BenchmarkThresholds(
                    absolute: [
                        .p90: 0  // we only record p90
                    ]
                ),
            ]
        )
    ) { _ in
        body(logger)
    }
}
