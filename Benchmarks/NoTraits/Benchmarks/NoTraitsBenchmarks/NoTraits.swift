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
import BenchmarksFactory
import Foundation
import Logging

public let benchmarks: @Sendable () -> Void = {

    makeBenchmark(loggerLevel: .error, logLevel: .error, "_generic") { logger in
        logger.log(level: .error, "hello, benchmarking world")
    }
    makeBenchmark(loggerLevel: .error, logLevel: .debug, "_generic") { logger in
        logger.log(level: .debug, "hello, benchmarking world")
    }

    // MARK: - Task-local logger benchmarks

    makeBenchmark(loggerLevel: .error, logLevel: .error, "_current_read_fallback") { _ in
        blackHole(Logger.current)
    }

    makeBenchmark(loggerLevel: .error, logLevel: .error, setScopedLogger: true, "_current_read_inside_scope") {
        logger in
        blackHole(Logger.current)
    }

    makeBenchmark(loggerLevel: .error, logLevel: .error, setScopedLogger: true, "_withLogger_mergingMetadata") {
        logger in
        withLogger(mergingMetadata: ["key": "value"]) { inner in
            blackHole(inner)
        }
    }

    makeBenchmark(loggerLevel: .error, logLevel: .error, setScopedLogger: true, "_withLogger_handler") { logger in
        withLogger(handler: logger.handler) { inner in
            blackHole(inner)
        }
    }

    makeBenchmark(loggerLevel: .error, logLevel: .error, "_1_attribute") { logger in
        logger.log(
            level: .error,
            "hello, benchmarking world",
            metadata: [
                "public-key": "\("public-value", sensitivity: .public)"
            ]
        )
    }
    makeBenchmark(loggerLevel: .error, logLevel: .debug, "_1_attribute") { logger in
        logger.log(
            level: .debug,
            "hello, benchmarking world",
            metadata: [
                "public-key": "\("public-value", sensitivity: .public)"
            ]
        )
    }
    makeBenchmark(loggerLevel: .error, logLevel: .error, "_2_attributes") { logger in
        logger.log(
            level: .error,
            "hello, benchmarking world",
            metadata: [
                "public-key": "\("public-value", attributes: [BenchmarkSensitivity.public, BenchmarkColor.red])"
            ]
        )
    }
    makeBenchmark(loggerLevel: .error, logLevel: .debug, "_2_attributes") { logger in
        logger.log(
            level: .debug,
            "hello, benchmarking world",
            metadata: [
                "public-key": "\("public-value", attributes: [BenchmarkSensitivity.public, BenchmarkColor.red])"
            ]
        )
    }
}
