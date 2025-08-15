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
import XCTest
import Logging

final class TaskLocalLoggerTests: XCTestCase {
    func test() async {
        let logger = Logger(label: "TestLogger") { StreamLogHandler.standardOutput(label: $0) }

        Logger.$logger.withValue(logger) {
            Logger.logger.info("Start log")
            var logger = Logger.logger
            logger[metadataKey: "MetadataKey1"] = "Value1"
            logger.logLevel = .trace
            Logger.$logger.withValue(logger) {
                Logger.logger.info("Log2")
            }
            Logger.logger.info("End log")
        }
    }
}
