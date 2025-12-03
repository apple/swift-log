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

let benchmarks: @Sendable () -> Void = {
    let iterations = 1_000_000
    let metrics: [BenchmarkMetric] = [.instructions, .objectAllocCount]

    // Take a pair of levels to cover all condition ranges between the active level and logged level.
    let logLevelParameterization: [Logger.Level] = [.debug, .error]
    for logLevel in logLevelParameterization {
        for logLevelUsed in logLevelParameterization {
            var logger = Logger(label: "BenchmarkRunner_\(logLevel)_\(logLevelUsed)")

            // Use a NoOpLogHandler to avoid polluting the logs
            logger.handler = NoOpLogHandler(label: "NoOpLogHandler")
            logger.logLevel = logLevel

            Benchmark(
                "\(logLevelUsed)_log_with_\(logLevel)_log_level",
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
            ) { benchmark in
                // This is what we actually benchmark
                logger.log(level: logLevelUsed, "hello, benchmarking world")
            }
        }
    }
}
