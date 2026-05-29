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

        #expect(logHandler.entries.count == 1)
        #expect(logHandler.entries[0].level == .info)
        #expect(logHandler.entries[0].message == "hello")
        #expect(logHandler.entries[0].metadata == ["key1": "value1", "key2": ["a", "b", "c"]])
    }

    @Test
    func metadataFromLoggerEndsUpInEntry() {
        var (logHandler, logger) = self.makeTestLogger()
        logger[metadataKey: "test"] = "value"
        logger.info("hello", metadata: ["key1": "value1", "key2": ["a", "b", "c"]])

        #expect(logHandler.entries.count == 1)
        #expect(logHandler.entries[0].level == .info)
        #expect(logHandler.entries[0].message == "hello")
        #expect(logHandler.entries[0].metadata == ["key1": "value1", "key2": ["a", "b", "c"], "test": "value"])
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

        #expect(logHandler.entries.count == 1)
        #expect(logHandler.entries[0].level == .info)
        #expect(logHandler.entries[0].message == "hello")
        #expect(logHandler.entries[0].metadata == ["a": "1", "b": "1", "c": "3"])
    }

    @Test
    func clear() {
        let (logHandler, logger) = self.makeTestLogger()
        logger.info("hello", metadata: ["key1": "value1", "key2": ["a", "b", "c"]])
        logHandler.clear()
        logger.info("hello2")

        #expect(logHandler.entries.count == 1)
        #expect(logHandler.entries[0].level == .info)
        #expect(logHandler.entries[0].message == "hello2")
        #expect(logHandler.entries[0].metadata == [:])
    }

    @Test
    func metadataWithAttributesIsPreservedInEntry() {
        var (logHandler, logger) = self.makeTestLogger()
        logger.logLevel = .trace
        logger[metadataKey: "global"] = "value"

        logger.log(
            level: .info,
            "test",
            metadata: [
                "key": "\("value", attributes: { _ in })"
            ]
        )

        #expect(logHandler.entries.count == 1)
        #expect(logHandler.entries[0].metadata["key"]?.description == "value")
        #expect(logHandler.entries[0].metadata["global"]?.description == "value")
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

    @Test
    func errorEquality() throws {
        let (logHandler, logger) = self.makeTestLogger()
        logger.info("hello", error: TestError.first)
        let entry = try #require(logHandler.entries.first)

        #expect(
            entry
                == InMemoryLogHandler.Entry(
                    level: .info,
                    message: "hello",
                    error: TestError.first,
                    metadata: [:]
                )
        )

        #expect(
            entry
                != InMemoryLogHandler.Entry(
                    level: .info,
                    message: "hello",
                    error: nil,
                    metadata: [:]
                )
        )

        #expect(
            entry
                != InMemoryLogHandler.Entry(
                    level: .info,
                    message: "hello",
                    error: TestError.second,
                    metadata: [:]
                )
        )

        #expect(
            entry
                != InMemoryLogHandler.Entry(
                    level: .info,
                    message: "hello",
                    error: Nested.TestError.first,
                    metadata: [:]
                )
        )
    }

    enum TestError: Error {
        case first
        case second
    }

    struct Nested {
        enum TestError: Error {
            case first
        }
    }
}
