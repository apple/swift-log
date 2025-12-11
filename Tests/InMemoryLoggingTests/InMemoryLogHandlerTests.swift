//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2018-2022 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import InMemoryLogging
import Logging
import Testing

struct InMemoryLogHandlerTests {
    @Test
    func collectsLogs() {
        let (logHandler, logger) = self.makeTestLogger()
        logger.info("hello", metadata: ["key1": "value1", "key2": ["a", "b", "c"]])

        #expect(
            logHandler.entries == [
                InMemoryLogHandler.Entry(
                    level: .info,
                    message: "hello",
                    metadata: ["key1": "value1", "key2": ["a", "b", "c"]]
                )
            ]
        )
    }

    @Test
    func metadataFromLoggerEndsUpInEntry() {
        var (logHandler, logger) = self.makeTestLogger()
        logger[metadataKey: "test"] = "value"
        logger.info("hello", metadata: ["key1": "value1", "key2": ["a", "b", "c"]])

        #expect(
            logHandler.entries == [
                InMemoryLogHandler.Entry(
                    level: .info,
                    message: "hello",
                    metadata: ["key1": "value1", "key2": ["a", "b", "c"], "test": "value"]
                )
            ]
        )
        // Metadata also sticks onto the logger
        #expect(logger[metadataKey: "test"] == "value")
    }

    @Test
    func moreSpecificMetadataOverridesGlobal() {
        let testProvider = Logger.MetadataProvider {
            ["a": "1", "b": "1", "c": "1"]
        }
        var (logHandler, logger) = self.makeTestLogger(metadataProvider: testProvider)
        logger[metadataKey: "b"] = "2"
        logger[metadataKey: "c"] = "2"
        logger.info("hello", metadata: ["c": "3"])

        #expect(
            logHandler.entries == [
                InMemoryLogHandler.Entry(level: .info, message: "hello", metadata: ["a": "1", "b": "2", "c": "3"])
            ]
        )
    }

    @Test
    func clear() {
        let (logHandler, logger) = self.makeTestLogger()
        logger.info("hello", metadata: ["key1": "value1", "key2": ["a", "b", "c"]])
        logHandler.clear()
        logger.info("hello2")

        // Only hello2 is here
        #expect(
            logHandler.entries == [
                InMemoryLogHandler.Entry(level: .info, message: "hello2", metadata: [:])
            ]
        )
    }

    private func makeTestLogger(metadataProvider: Logger.MetadataProvider? = nil) -> (InMemoryLogHandler, Logger) {
        var logHandler = InMemoryLogHandler()
        logHandler.metadataProvider = metadataProvider
        let logger = Logger(
            label: "MyApp",
            factory: { _ in
                logHandler
            }
        )
        return (logHandler, logger)
    }
}
