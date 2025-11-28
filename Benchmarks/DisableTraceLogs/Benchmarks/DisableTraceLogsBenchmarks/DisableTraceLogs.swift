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
    makeBenchmark(loggerLevel: .trace, logLevel: .trace) { logger in
        logger.trace("hello, benchmarking world")
    }
    makeBenchmark(loggerLevel: .trace, logLevel: .trace, "_generic") { logger in
        logger.log(level: .trace, "hello, benchmarking world")
    }
}
