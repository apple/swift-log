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

func nothingFunc() {
    // nothing
}

let benchmarks: @Sendable () -> Void = {
    let iterations = 100
    let metrics: [BenchmarkMetric] = [.instructions, .objectAllocCount]

    Benchmark(
        "Nothing benchmark",
        configuration: .init(
            metrics: metrics,
            maxIterations: iterations,
            thresholds: [.instructions: .init(absolute: [.p90: 0])]
        )
    ) { benchmark in
        blackHole(nothingFunc())
    }

    let logLevelParameterization: [Logger.Level] = Logger.Level.allCases
    for logLevel in logLevelParameterization {
        for logLevelUsed in logLevelParameterization {
            var logger = Logger(label: "BenchmarkRunner_\(logLevel)_\(logLevelUsed)")
            logger.logLevel = logLevel
            Benchmark(
                "\(logLevelUsed) log with \(logLevel) log level",
                configuration: .init(
                    metrics: metrics,
                    maxIterations: iterations
                )
            ) { benchmark in
                // This is what we actually benchmark
                logger.log(level: logLevelUsed, "hello, benchmarking world")
            }
        }
    }
}
