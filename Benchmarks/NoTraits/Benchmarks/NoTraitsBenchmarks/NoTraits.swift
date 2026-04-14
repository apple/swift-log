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
import LoggingAttributes

/// Dummy attribute for benchmarking the 2-attribute (overflow) path.
enum Color: Int, Logger.MetadataAttributeKey, Sendable {
    case red = 1
    case blue = 2
}

public let benchmarks: @Sendable () -> Void = {
    makeBenchmark(loggerLevel: .error, logLevel: .error, "_generic") { logger in
        logger.log(level: .error, "hello, benchmarking world")
    }
    makeBenchmark(loggerLevel: .error, logLevel: .debug, "_generic") { logger in
        logger.log(level: .debug, "hello, benchmarking world")
    }
    makeBenchmark(loggerLevel: .error, logLevel: .error, "_1_attribute") { logger in
        logger.log(
            level: .error,
            "hello, benchmarking world",
            attributedMetadata: [
                "public-key": "\("public-value", sensitivity: .public)"
            ]
        )
    }
    makeBenchmark(loggerLevel: .error, logLevel: .debug, "_1_attribute") { logger in
        logger.log(
            level: .debug,
            "hello, benchmarking world",
            attributedMetadata: [
                "public-key": "\("public-value", sensitivity: .public)"
            ]
        )
    }
    makeBenchmark(loggerLevel: .error, logLevel: .error, "_2_attributes") { logger in
        var attrs = Logger.MetadataValueAttributes()
        attrs[Logger.Sensitivity.self] = .public
        attrs[Color.self] = .red
        logger.log(
            level: .error,
            "hello, benchmarking world",
            attributedMetadata: [
                "public-key": Logger.AttributedMetadataValue(.string("public-value"), attributes: attrs)
            ]
        )
    }
    makeBenchmark(loggerLevel: .error, logLevel: .debug, "_2_attributes") { logger in
        var attrs = Logger.MetadataValueAttributes()
        attrs[Logger.Sensitivity.self] = .public
        attrs[Color.self] = .red
        logger.log(
            level: .debug,
            "hello, benchmarking world",
            attributedMetadata: [
                "public-key": Logger.AttributedMetadataValue(.string("public-value"), attributes: attrs)
            ]
        )
    }
}
