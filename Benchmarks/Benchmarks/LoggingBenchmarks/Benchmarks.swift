//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Benchmark
import Logging

let benchmarks = {
    let defaultMetrics: [BenchmarkMetric] = [
        .mallocCountTotal,
        .instructions,
        .wallClock,
    ]

    Benchmark(
        "NoOpLogger",
        configuration: Benchmark.Configuration(
            metrics: defaultMetrics,
            scalingFactor: .mega,
            maxDuration: .seconds(10_000_000),
            maxIterations: 100
        )
    ) { benchmark in
        let logger = Logger(label: "Logger", SwiftLogNoOpLogHandler())

        for _ in 0..<benchmark.scaledIterations.upperBound {
            logger.info("Log message")
        }
    }

    Benchmark(
        "NoOpLogger task local",
        configuration:  Benchmark.Configuration(
            metrics: defaultMetrics,
            scalingFactor: .mega,
            maxDuration: .seconds(10_000_000),
            maxIterations: 100
        )
    ) { benchmark in
        let logger = Logger(label: "Logger", SwiftLogNoOpLogHandler())

        Logger.$logger.withValue(logger) {
            for _ in 0..<benchmark.scaledIterations.upperBound {
                Logger.logger.info("Log message")
            }
        }
    }
}
