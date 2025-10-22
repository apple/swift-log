//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Testing

@testable import Logging

struct SendableTest {
    @Test func sendableLogger() async {
        let testLogging = TestLogging()

        let logger = Logger(
            label: "test",
            factory: {
                testLogging.make(label: $0)
            }
        )
        let message1 = Logger.Message(stringLiteral: "critical 1")
        let message2 = Logger.Message(stringLiteral: "critical 2")
        let metadata: Logger.Metadata = ["key": "value"]

        let task = Task.detached {
            logger.info("info")
            logger.critical(message1)
            logger.critical(message2)
            logger.warning(.init(stringLiteral: "warning"), metadata: metadata)
        }

        await task.value
        testLogging.history.assertExist(level: .info, message: "info", metadata: [:])
        testLogging.history.assertExist(level: .critical, message: "critical 1", metadata: [:])
        testLogging.history.assertExist(level: .critical, message: "critical 2", metadata: [:])
        testLogging.history.assertExist(level: .warning, message: "warning", metadata: metadata)
    }
}
