//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2018-2025 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(os) && compiler(>=6.0)
import Logging
import OSLogLogHandler
import Testing

@Suite("OSLog Handler Tests")
struct OSLogHandlerTests {
    // MARK: - Test Data

    private enum TestData {
        static let subsystem = "com.example.test"
        static let category = "test-category"
        static let userId = "user-12345"
        static let sessionId = "session-67890"
    }

    // MARK: - Initialization Tests

    @Test("OSLogHandler can be initialized")
    func testInitialization() {
        guard #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) else {
            return
        }

        let handler = OSLogHandler(subsystem: TestData.subsystem, category: TestData.category)
        #expect(handler.logLevel == .info)
        #expect(handler.metadata.isEmpty)
        #expect(handler.metadataProvider == nil)
        #expect(handler.attributedMetadata.isEmpty)
    }

    @Test("OSLogHandler integrates with Logger")
    func testLoggerIntegration() {
        guard #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) else {
            return
        }

        let handler = OSLogHandler(subsystem: TestData.subsystem, category: TestData.category)
        let logger = Logger(label: "test") { _ in handler }
        #expect(logger.logLevel == .info)
    }

    // MARK: - Plain Metadata Tests

    @Test("OSLogHandler logs plain metadata")
    func testPlainMetadataLogging() {
        guard #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) else {
            return
        }

        let handler = OSLogHandler(subsystem: TestData.subsystem, category: TestData.category)
        let logger = Logger(label: "test") { _ in handler }

        // Should not crash - actual log output goes to system logs
        logger.info("Plain message", metadata: ["key": "value"])
    }

    @Test("OSLogHandler supports all log levels")
    func testAllLogLevels() {
        guard #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) else {
            return
        }

        var handler = OSLogHandler(subsystem: TestData.subsystem, category: TestData.category)
        handler.logLevel = .trace
        let logger = Logger(label: "test") { _ in handler }

        // Test all levels - should not crash
        logger.trace("Trace message")
        logger.debug("Debug message")
        logger.info("Info message")
        logger.notice("Notice message")
        logger.warning("Warning message")
        logger.error("Error message")
        logger.critical("Critical message")
    }

    // MARK: - Attributed Metadata Tests

    @Test("OSLogHandler logs attributed metadata with privacy")
    func testAttributedMetadataWithPrivacy() {
        guard #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) else {
            return
        }

        let handler = OSLogHandler(subsystem: TestData.subsystem, category: TestData.category)
        let logger = Logger(label: "test") { _ in handler }

        // Should not crash - privacy is handled by OSLog
        logger.info(
            "User action",
            attributedMetadata: [
                "user.id": "\(TestData.userId, privacy: .private)",
                "action": "\("login", privacy: .public)",
            ]
        )
    }

    @Test("OSLogHandler handles empty attributed metadata")
    func testEmptyAttributedMetadata() {
        guard #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) else {
            return
        }

        let handler = OSLogHandler(subsystem: TestData.subsystem, category: TestData.category)
        let logger = Logger(label: "test") { _ in handler }

        logger.info("Message with empty metadata", attributedMetadata: [:])
    }

    @Test("OSLogHandler handles nil attributed metadata")
    func testNilAttributedMetadata() {
        guard #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) else {
            return
        }

        let handler = OSLogHandler(subsystem: TestData.subsystem, category: TestData.category)
        let logger = Logger(label: "test") { _ in handler }

        logger.log(level: .info, "Message", attributedMetadata: nil)
    }

    // MARK: - Metadata Storage Tests

    @Test("Handler metadata storage via subscript")
    func testHandlerMetadataSubscript() {
        guard #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) else {
            return
        }

        var handler = OSLogHandler(subsystem: TestData.subsystem, category: TestData.category)

        handler[metadataKey: "key1"] = "value1"
        #expect(handler[metadataKey: "key1"]?.description == "value1")

        handler[metadataKey: "key1"] = "updated"
        #expect(handler[metadataKey: "key1"]?.description == "updated")

        handler[metadataKey: "key1"] = nil
        #expect(handler[metadataKey: "key1"] == nil)
    }

    @Test("Handler attributed metadata storage via subscript")
    func testHandlerAttributedMetadataSubscript() {
        guard #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) else {
            return
        }

        var handler = OSLogHandler(subsystem: TestData.subsystem, category: TestData.category)

        handler[attributedMetadataKey: "user.id"] = "\(TestData.userId, privacy: .private)"
        #expect(handler[attributedMetadataKey: "user.id"]?.attributes.privacy == .private)
        #expect(handler[attributedMetadataKey: "user.id"]?.value.description == TestData.userId)

        handler[attributedMetadataKey: "user.id"] = nil
        #expect(handler[attributedMetadataKey: "user.id"] == nil)
    }

    @Test("Handler plain metadata property")
    func testHandlerPlainMetadataProperty() {
        guard #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) else {
            return
        }

        var handler = OSLogHandler(subsystem: TestData.subsystem, category: TestData.category)

        handler.metadata = ["key1": "value1", "key2": "value2"]
        #expect(handler.metadata.count == 2)
        #expect(handler.metadata["key1"]?.description == "value1")
    }

    @Test("Handler attributed metadata property")
    func testHandlerAttributedMetadataProperty() {
        guard #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) else {
            return
        }

        var handler = OSLogHandler(subsystem: TestData.subsystem, category: TestData.category)

        handler.attributedMetadata = [
            "public-key": "\("public-value", privacy: .public)",
            "private-key": "\("private-value", privacy: .private)",
        ]

        #expect(handler.attributedMetadata.count == 2)
        #expect(handler.attributedMetadata["public-key"]?.attributes.privacy == .public)
        #expect(handler.attributedMetadata["private-key"]?.attributes.privacy == .private)
    }
}
#endif
