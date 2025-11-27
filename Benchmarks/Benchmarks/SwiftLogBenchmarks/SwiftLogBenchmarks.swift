//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Benchmark
import Foundation
import Logging

func makeBenchmark(
    loggerLevel: Logger.Level,
    logLevel: Logger.Level,
    _ extraNameSuffix: String = "",
    _ body: @escaping (Logger) -> Void
) {
    let iterations = 1_000_000
    let metrics: [BenchmarkMetric] = [.instructions, .objectAllocCount]

    var logger = Logger(label: "BenchmarkRunner_\(loggerLevel)_\(logLevel)")

    // Use a NoOpLogHandler to avoid polluting the logs
    logger.handler = NoOpLogHandler(label: "NoOpLogHandler")
    logger.logLevel = loggerLevel

    Benchmark(
        "\(loggerLevel)_log_with_\(logLevel)_log_level\(extraNameSuffix)",
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

let benchmarks: @Sendable () -> Void = {
    // Generic .log method. Should honor both runtime checks and `DisableXXXTrait`s,
    // but does not offer any performance benefits.
    makeBenchmark(loggerLevel: .error, logLevel: .debug) { logger in
        logger.log(level: .debug, "hello, benchmarking world")
    }
    makeBenchmark(loggerLevel: .error, logLevel: .error) { logger in
        logger.log(level: .error, "hello, benchmarking world")
    }

    // Level-specific methods should compile-out logging with the corresponding traits.
    makeBenchmark(loggerLevel: .trace, logLevel: .trace, "_DisableTraceLogs") { logger in
        logger.trace("hello, benchmarking world")
    }
    makeBenchmark(loggerLevel: .debug, logLevel: .debug, "_DisableDebugLogs") { logger in
        logger.debug("hello, benchmarking world")
    }
    makeBenchmark(loggerLevel: .info, logLevel: .info, "_DisableInfoLogs") { logger in
        logger.info("hello, benchmarking world")
    }
    makeBenchmark(loggerLevel: .notice, logLevel: .notice, "_DisableNoticeLogs") { logger in
        logger.notice("hello, benchmarking world")
    }
    makeBenchmark(loggerLevel: .warning, logLevel: .warning, "_DisableWarningLogs") { logger in
        logger.warning("hello, benchmarking world")
    }
    makeBenchmark(loggerLevel: .error, logLevel: .error, "_DisableErrorLogs") { logger in
        logger.error("hello, benchmarking world")
    }
    makeBenchmark(loggerLevel: .critical, logLevel: .critical, "_DisableCriticalLogs") { logger in
        logger.critical("hello, benchmarking world")
    }
}
