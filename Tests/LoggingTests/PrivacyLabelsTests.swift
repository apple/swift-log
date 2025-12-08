//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Testing

@testable import Logging

@Suite("Privacy Labels Tests")
struct PrivacyLabelsTests {

    // MARK: - Test Data Constants

    private enum TestData {
        static let userId = UUID(uuidString: "12345678-1234-5678-1234-567812345678")!
        static let action = "login"
        static let sessionId = UUID(uuidString: "87654321-4321-8765-4321-876543218765")!
        static let requestId = UUID(uuidString: "ABCDEF01-2345-6789-ABCD-EF0123456789")!
        static let redactionMarker = "***"
        // Use the same redaction marker as the library for assertions
        static let privateMarker = Logger.AttributedMetadataValue.redactionMarker
    }

    // MARK: - Test Fixtures

    private func makeRecorderLogger() -> (PrivacyLogRecorder, Logger) {
        let recorder = PrivacyLogRecorder()
        let handler = PrivacyTestLogHandler(recorder: recorder)
        var logger = Logger(label: "test") { _ in handler }
        logger.logLevel = .trace
        return (recorder, logger)
    }

    private func makeStreamLogger(
        privacyBehavior: PrivacyAwareLogHandlerWrapper.PrivacyBehavior = .redact
    )
        -> (TestOutputStream, Logger)
    {
        let stream = TestOutputStream()
        let streamHandler = StreamLogHandler(label: "test", stream: stream, metadataProvider: nil)
        let handler = PrivacyAwareLogHandlerWrapper(wrapping: streamHandler, privacyBehavior: privacyBehavior)
        return (stream, Logger(label: "test") { _ in handler })
    }

    // MARK: - Tests

    @Test("PrivacyLevel enum properties")
    func testPrivacyLevel() {
        #expect(Logger.PrivacyLevel.private.rawValue == "private")
        #expect(Logger.PrivacyLevel.public.rawValue == "public")
        #expect(Logger.PrivacyLevel.allCases.contains(.private))
        #expect(Logger.PrivacyLevel.allCases.contains(.public))
    }

    @Test("MetadataValueAttributes initialization")
    func testMetadataValueAttributes() {
        let defaultAttrs = Logger.MetadataValueAttributes()
        #expect(defaultAttrs.privacy == .public)

        let publicAttrs = Logger.MetadataValueAttributes(privacy: .public)
        #expect(publicAttrs.privacy == .public)

        let privateAttrs = Logger.MetadataValueAttributes(privacy: .private)
        #expect(privateAttrs.privacy == .private)
    }

    @Test("AttributedMetadataValue initialization")
    func testAttributedMetadataValue() {
        let value = Logger.MetadataValue.string("test")
        let attributes = Logger.MetadataValueAttributes(privacy: .public)

        let attributed1 = Logger.AttributedMetadataValue(value, attributes: attributes)
        #expect(attributed1.value.description == "test")
        #expect(attributed1.attributes.privacy == .public)

        let attributed2 = Logger.AttributedMetadataValue(value, privacy: .private)
        #expect(attributed2.value.description == "test")
        #expect(attributed2.attributes.privacy == .private)
    }

    @Test("String interpolation API usage")
    func testStringInterpolationAPI() {
        // Test string interpolation as described in the proposal
        let metadata: Logger.AttributedMetadata = [
            "user.id": "\(TestData.userId, privacy: .private)",
            "action": "\(TestData.action, privacy: .public)",
            "timestamp": "\("2024-01-01", privacy: .public)",
            "settings": .init(
                .dictionary(["theme": .string("dark"), "notifications": .string("enabled")]),
                privacy: .private
            ),
            "features": .init(.array([.string("feature1"), .string("feature2")]), privacy: .public),
            "session.id": "\(TestData.sessionId, privacy: .private)",
            "endpoint": "\("/api/v1/login", privacy: .public)",
            "source": "\("mobile-app", privacy: .public)",
        ]

        #expect(metadata.count == 8)
        #expect(metadata["user.id"]?.attributes.privacy == .private)
        #expect(metadata["action"]?.attributes.privacy == .public)
        #expect(metadata["timestamp"]?.attributes.privacy == .public)
        #expect(metadata["settings"]?.attributes.privacy == .private)
        #expect(metadata["features"]?.attributes.privacy == .public)
        #expect(metadata["session.id"]?.attributes.privacy == .private)
        #expect(metadata["endpoint"]?.attributes.privacy == .public)
        #expect(metadata["source"]?.attributes.privacy == .public)
    }

    @Test("Attributed metadata logging")
    func testAttributedMetadataLogging() {
        let (recorder, logger) = makeRecorderLogger()

        let attributedMetadata: Logger.AttributedMetadata = [
            "user.id": "\(TestData.userId, privacy: .private)",
            "action": "\(TestData.action, privacy: .public)",
        ]

        logger.log(level: .info, "User action", attributedMetadata: attributedMetadata)

        #expect(recorder.messages.count == 1)
        #expect(recorder.messages[0].level == .info)
        #expect(recorder.messages[0].message.description == "User action")
        #expect(recorder.messages[0].attributedMetadata != nil)
        #expect(recorder.messages[0].attributedMetadata?["user.id"]?.attributes.privacy == .private)
        #expect(recorder.messages[0].attributedMetadata?["action"]?.attributes.privacy == .public)
    }

    @Test("Global plain metadata is merged with attributed metadata as public")
    func testGlobalMetadataIsMergedWithAttributed() {
        let (recorder, logger) = makeRecorderLogger()
        var mutableLogger = logger

        // Set some global metadata via subscript
        mutableLogger[metadataKey: "service"] = "auth-service"
        mutableLogger[metadataKey: "version"] = "1.0"

        // Log with specific attributed metadata
        mutableLogger.log(
            level: .info,
            "Processing request",
            attributedMetadata: [
                "request.id": "\(TestData.requestId, privacy: .public)",
                "user.id": "\("user-456", privacy: .private)",
            ]
        )

        #expect(recorder.messages.count == 1)

        let finalMetadata = recorder.messages[0].attributedMetadata
        #expect(finalMetadata != nil)

        // Global metadata SHOULD be present in attributed logging, converted to public
        #expect(finalMetadata?["service"]?.attributes.privacy == .public)
        #expect(finalMetadata?["service"]?.value.description == "auth-service")
        #expect(finalMetadata?["version"]?.attributes.privacy == .public)
        #expect(finalMetadata?["version"]?.value.description == "1.0")

        // Log-specific metadata should also be present with their specified privacy levels
        #expect(finalMetadata?["request.id"]?.attributes.privacy == .public)
        #expect(finalMetadata?["user.id"]?.attributes.privacy == .private)
        #expect(finalMetadata?.count == 4)
    }

    @Test("Plain metadata and attributed metadata are separate paths")
    func testPlainAndAttributedSeparatePaths() {
        let (recorder, logger) = makeRecorderLogger()

        // Plain metadata logging should call the plain handler method
        logger.info(
            "Plain logging",
            metadata: [
                "key1": "value1",
                "key2": "value2",
            ]
        )

        #expect(recorder.messages.count == 1)

        // Should receive plain metadata, not attributed
        #expect(recorder.messages[0].metadata != nil)
        #expect(recorder.messages[0].attributedMetadata == nil)
        #expect(recorder.messages[0].metadata?["key1"]?.description == "value1")
        #expect(recorder.messages[0].metadata?["key2"]?.description == "value2")
    }

    @Test("Default handler implementation redacts private metadata")
    func testDefaultHandlerRedactsPrivateMetadata() {
        // Test the default LogHandler extension that redacts private metadata
        let recorder = FilterLogRecorder()
        let handler = FilterTestLogHandler(recorder: recorder)

        let attributedMetadata: Logger.AttributedMetadata = [
            "public_key": "\("public_value", privacy: .public)",
            "private_key": "\("private_value", privacy: .private)",
            "another_public": "\("another_public_value", privacy: .public)",
        ]

        handler.log(
            level: .info,
            message: "Test message",
            attributedMetadata: attributedMetadata,
            source: "test",
            file: "test.swift",
            function: "testFunc",
            line: 42
        )

        // Public metadata should be present normally
        // Private metadata should be redacted to "<private>"
        #expect(recorder.receivedMetadata != nil)
        #expect(recorder.receivedMetadata?.count == 3)
        #expect(recorder.receivedMetadata?["public_key"]?.description == "public_value")
        #expect(recorder.receivedMetadata?["another_public"]?.description == "another_public_value")
        #expect(recorder.receivedMetadata?["private_key"]?.description == TestData.privateMarker)
    }

    @Test("PrivacyAwareLogHandlerWrapper redacts private metadata")
    func testPrivacyAwareLogHandlerWrapperRedaction() {
        let (stream, logger) = makeStreamLogger()

        logger.log(
            level: .info,
            "User action",
            attributedMetadata: [
                "user.id": "\(TestData.userId, privacy: .private)",
                "action": "\(TestData.action, privacy: .public)",
                "session.id": "\(TestData.sessionId, privacy: .private)",
            ]
        )

        // Check that private values are redacted as ***
        #expect(stream.output.contains("action=\(TestData.action)"))
        #expect(stream.output.contains("user.id=\(TestData.redactionMarker)"))
        #expect(stream.output.contains("session.id=\(TestData.redactionMarker)"))
        #expect(!stream.output.contains(TestData.userId.uuidString))
        #expect(!stream.output.contains(TestData.sessionId.uuidString))
    }

    @Test("PrivacyAwareLogHandlerWrapper logs private metadata when configured")
    func testPrivacyAwareLogHandlerWrapperLogsPrivate() {
        let (stream, logger) = makeStreamLogger(privacyBehavior: .log)

        logger.log(
            level: .info,
            "User action",
            attributedMetadata: [
                "user.id": "\(TestData.userId, privacy: .private)",
                "action": "\(TestData.action, privacy: .public)",
            ]
        )

        // Check that private values are logged normally
        #expect(stream.output.contains("user.id=\(TestData.userId.uuidString)"))
        #expect(stream.output.contains("action=\(TestData.action)"))
        #expect(!stream.output.contains(TestData.redactionMarker))
    }

    @Test("PrivacyAwareLogHandlerWrapper factory pattern works")
    func testPrivacyAwareLogHandlerWrapperFactoryPattern() {
        // Test creating wrapper with default behavior
        let streamHandler1 = StreamLogHandler.standardOutput(label: "stdout-test")
        let wrapper1 = PrivacyAwareLogHandlerWrapper(wrapping: streamHandler1)
        #expect(wrapper1.logLevel == .info)
        #expect(wrapper1.privacyBehavior == .redact)

        // Test creating wrapper with custom behavior
        let streamHandler2 = StreamLogHandler.standardError(label: "stderr-test")
        let wrapper2 = PrivacyAwareLogHandlerWrapper(wrapping: streamHandler2, privacyBehavior: .log)
        #expect(wrapper2.logLevel == .info)
        #expect(wrapper2.privacyBehavior == .log)

        // Test with metadata provider
        let provider = Logger.MetadataProvider { ["env": "test"] }
        var streamHandler3 = StreamLogHandler.standardOutput(label: "test")
        streamHandler3.metadataProvider = provider
        let wrapper3 = PrivacyAwareLogHandlerWrapper(wrapping: streamHandler3)
        #expect(wrapper3.metadataProvider != nil)
        #expect(wrapper3.privacyBehavior == .redact)
    }

    @Test("PrivacyAwareLogHandlerWrapper handles plain metadata")
    func testPrivacyAwareLogHandlerWrapperPlainMetadata() {
        let stream = TestOutputStream()

        let streamHandler = StreamLogHandler(label: "test", stream: stream, metadataProvider: nil)
        let handler = PrivacyAwareLogHandlerWrapper(wrapping: streamHandler)

        let logger = Logger(label: "test") { _ in handler }

        // Plain metadata should work normally
        logger.info("Plain message", metadata: ["key": "value", "count": "42"])

        #expect(stream.output.contains("key=value"))
        #expect(stream.output.contains("count=42"))
    }

    @Test("PrivacyAwareLogHandlerWrapper merges global metadata")
    func testPrivacyAwareLogHandlerWrapperGlobalMetadata() {
        let stream = TestOutputStream()
        let streamHandler = StreamLogHandler(label: "test", stream: stream, metadataProvider: nil)
        var handler = PrivacyAwareLogHandlerWrapper(wrapping: streamHandler, privacyBehavior: .redact)
        handler[metadataKey: "service"] = "auth"
        handler[metadataKey: "version"] = "1.0"

        let logger = Logger(label: "test") { _ in handler }

        logger.log(
            level: .info,
            "Request",
            attributedMetadata: [
                "user.id": "\(TestData.userId, privacy: .private)",
                "request.id": "\(TestData.requestId, privacy: .public)",
            ]
        )

        // Global metadata should appear (treated as public)
        #expect(stream.output.contains("service=auth"))
        #expect(stream.output.contains("version=1.0"))
        // Public attributed metadata should appear
        #expect(stream.output.contains("request.id=\(TestData.requestId.uuidString)"))
        // Private attributed metadata should be redacted
        #expect(stream.output.contains("user.id=\(TestData.redactionMarker)"))
        #expect(!stream.output.contains(TestData.userId.uuidString))
    }

    @Test("Handler privacyBehavior property")
    func testHandlerPrivacyBehavior() {
        let streamHandler = StreamLogHandler.standardOutput(label: "test")
        var handler = PrivacyAwareLogHandlerWrapper(wrapping: streamHandler)

        // Default should be .redact
        #expect(handler.privacyBehavior == .redact)

        // Should be able to change it
        handler.privacyBehavior = .log
        #expect(handler.privacyBehavior == .log)

        // Should support value semantics (COW via struct)
        var handler2 = handler
        handler2.privacyBehavior = .redact
        #expect(handler.privacyBehavior == .log)
        #expect(handler2.privacyBehavior == .redact)
    }

    @Test("Logger attributedMetadata property")
    func testLoggerAttributedMetadataProperty() {
        let (_, logger) = makeRecorderLogger()
        var mutableLogger = logger

        // Set attributed metadata on logger
        mutableLogger.attributedMetadata = [
            "user.id": "\(TestData.userId, privacy: .private)",
            "action": "\(TestData.action, privacy: .public)",
        ]

        #expect(mutableLogger.attributedMetadata.count == 2)
        #expect(mutableLogger.attributedMetadata["user.id"]?.attributes.privacy == .private)
        #expect(mutableLogger.attributedMetadata["action"]?.attributes.privacy == .public)
    }

    @Test("Logger attributedMetadata subscript")
    func testLoggerAttributedMetadataSubscript() {
        let (_, logger) = makeRecorderLogger()
        var mutableLogger = logger

        // Set attributed metadata via subscript
        mutableLogger[attributedMetadataKey: "user.id"] = "\(TestData.userId, privacy: .private)"
        mutableLogger[attributedMetadataKey: "action"] = "\(TestData.action, privacy: .public)"

        #expect(mutableLogger[attributedMetadataKey: "user.id"]?.attributes.privacy == .private)
        #expect(mutableLogger[attributedMetadataKey: "action"]?.attributes.privacy == .public)

        // Update attributed metadata
        let newUserId = "67890"
        mutableLogger[attributedMetadataKey: "user.id"] = "\(newUserId, privacy: .public)"
        #expect(mutableLogger[attributedMetadataKey: "user.id"]?.attributes.privacy == .public)
        #expect(mutableLogger[attributedMetadataKey: "user.id"]?.value.description == "67890")
    }

    @Test("LogHandler attributedMetadata property")
    func testLogHandlerAttributedMetadataProperty() {
        let streamHandler = StreamLogHandler.standardOutput(label: "test")
        var handler = PrivacyAwareLogHandlerWrapper(wrapping: streamHandler)

        let service = "auth"
        let version = "1.0"

        // Set attributed metadata on handler
        handler.attributedMetadata = [
            "service": "\(service, privacy: .public)",
            "version": "\(version, privacy: .public)",
        ]

        #expect(handler.attributedMetadata.count == 2)
        #expect(handler.attributedMetadata["service"]?.attributes.privacy == .public)
        #expect(handler.attributedMetadata["version"]?.attributes.privacy == .public)
    }

    @Test("LogHandler attributedMetadata subscript")
    func testLogHandlerAttributedMetadataSubscript() {
        let streamHandler = StreamLogHandler.standardOutput(label: "test")
        var handler = PrivacyAwareLogHandlerWrapper(wrapping: streamHandler)

        let service = "auth"
        let version = "1.0"

        // Set attributed metadata via subscript
        handler[attributedMetadataKey: "service"] = "\(service, privacy: .public)"
        handler[attributedMetadataKey: "version"] = "\(version, privacy: .private)"

        #expect(handler[attributedMetadataKey: "service"]?.attributes.privacy == .public)
        #expect(handler[attributedMetadataKey: "version"]?.attributes.privacy == .private)

        // Remove attributed metadata
        handler[attributedMetadataKey: "version"] = nil
        #expect(handler[attributedMetadataKey: "version"] == nil)
        #expect(handler.attributedMetadata.count == 1)
    }

    @Test("Logger value semantics for attributed metadata")
    func testLoggerValueSemanticsAttributedMetadata() {
        let recorder = PrivacyLogRecorder()
        var logger1 = Logger(label: "test") { _ in PrivacyTestLogHandler(recorder: recorder) }

        let value1 = "value1"
        let value2 = "value2"

        logger1[attributedMetadataKey: "key1"] = Logger.AttributedMetadataValue(.string(value1), privacy: .private)

        var logger2 = logger1
        logger2[attributedMetadataKey: "key2"] = Logger.AttributedMetadataValue(.string(value2), privacy: .public)

        // logger1 should not have key2
        #expect(logger1[attributedMetadataKey: "key1"]?.value.description == "value1")
        #expect(logger1[attributedMetadataKey: "key2"] == nil)

        // logger2 should have both
        #expect(logger2[attributedMetadataKey: "key1"]?.value.description == "value1")
        #expect(logger2[attributedMetadataKey: "key2"]?.value.description == "value2")
    }

    @Test("String interpolation with privacy parameter")
    func testStringInterpolationWithPrivacy() {
        // Test interpolation with explicit privacy
        let privateValue: Logger.AttributedMetadataValue = "\(TestData.userId, privacy: .private)"
        #expect(privateValue.value.description == TestData.userId.uuidString)
        #expect(privateValue.attributes.privacy == .private)

        let publicValue: Logger.AttributedMetadataValue = "\(TestData.action, privacy: .public)"
        #expect(publicValue.value.description == TestData.action)
        #expect(publicValue.attributes.privacy == .public)

        // Test multiple interpolations (strictest privacy wins)
        let mixedPrivateFirst: Logger.AttributedMetadataValue =
            "User \(TestData.userId, privacy: .private) performed \(TestData.action, privacy: .public)"
        #expect(
            mixedPrivateFirst.value.description == "User \(TestData.userId.uuidString) performed \(TestData.action)"
        )
        #expect(mixedPrivateFirst.attributes.privacy == .private)

        // Test multiple interpolations (strictest privacy wins)
        let mixedPublicFirst: Logger.AttributedMetadataValue =
            "User \(TestData.userId, privacy: .public) performed \(TestData.action, privacy: .private)"
        #expect(mixedPublicFirst.value.description == "User \(TestData.userId.uuidString) performed \(TestData.action)")
        #expect(mixedPublicFirst.attributes.privacy == .private)

        // Test string literal (defaults to public)
        let literal: Logger.AttributedMetadataValue = "literal value"
        #expect(literal.value.description == "literal value")
        #expect(literal.attributes.privacy == .public)

        // Test interpolation without privacy parameter (defaults to public)
        let defaultPrivacy: Logger.AttributedMetadataValue = "\(TestData.userId)"
        #expect(defaultPrivacy.value.description == TestData.userId.uuidString)
        #expect(defaultPrivacy.attributes.privacy == .public)
    }

    @Test("String interpolation in logging")
    func testStringInterpolationInLogging() {
        let (recorder, logger) = makeRecorderLogger()

        logger.log(
            level: .info,
            "User action",
            attributedMetadata: [
                "user.id": "\(TestData.userId, privacy: .private)",
                "action": "\(TestData.action, privacy: .public)",
                "session": "sess-\(TestData.userId, privacy: .private)",
            ]
        )

        #expect(recorder.messages.count == 1)
        let metadata = recorder.messages[0].attributedMetadata
        #expect(metadata != nil)
        #expect(metadata?["user.id"]?.attributes.privacy == .private)
        #expect(metadata?["user.id"]?.value.description == TestData.userId.uuidString)
        #expect(metadata?["action"]?.attributes.privacy == .public)
        #expect(metadata?["action"]?.value.description == TestData.action)
        #expect(metadata?["session"]?.attributes.privacy == .private)
        #expect(metadata?["session"]?.value.description == "sess-\(TestData.userId.uuidString)")
    }

    @Test("MetadataProvider factory methods")
    func testMetadataProviderFactoryMethods() {
        // Test plain .init
        let plainProvider = Logger.MetadataProvider {
            ["service": "test-service", "version": "1.0"]
        }

        let plainMetadata = plainProvider.get()
        #expect(plainMetadata["service"]?.description == "test-service")
        #expect(plainMetadata["version"]?.description == "1.0")

        // Test attributed .init
        let attributedProvider = Logger.MetadataProvider {
            [
                "public-key": "\("public-value", privacy: .public)",
                "private-key": "\("private-value", privacy: .private)",
            ]
        }

        let attributedMetadata = attributedProvider.getAttributed()
        #expect(attributedMetadata != nil)
        #expect(attributedMetadata?["public-key"]?.attributes.privacy == .public)
        #expect(attributedMetadata?["private-key"]?.attributes.privacy == .private)
    }

    @Test("MetadataProvider getAttributed method")
    func testMetadataProviderGetAttributed() {
        // Plain provider should return nil from getAttributed
        let plainProvider = Logger.MetadataProvider {
            ["key": "value"]
        }
        #expect(plainProvider.getAttributed() == nil)

        // Attributed provider should return attributed metadata
        let attributedProvider = Logger.MetadataProvider {
            [
                "user-id": "\("12345", privacy: .private)",
                "request-id": "\("req-789", privacy: .public)",
            ]
        }

        let attributed = attributedProvider.getAttributed()
        #expect(attributed != nil)
        #expect(attributed?.count == 2)
        #expect(attributed?["user-id"]?.value.description == "12345")
        #expect(attributed?["user-id"]?.attributes.privacy == .private)
        #expect(attributed?["request-id"]?.value.description == "req-789")
        #expect(attributed?["request-id"]?.attributes.privacy == .public)
    }

    @Test("Attributed provider get() redacts private values")
    func testAttributedProviderGetRedactsPrivate() {
        // Attributed provider should redact private values when called through get()
        let provider = Logger.MetadataProvider {
            [
                "public-data": "\("visible", privacy: .public)",
                "private-data": "\("secret", privacy: .private)",
                "another-public": "\("also-visible", privacy: .public)",
            ]
        }

        let plainMetadata = provider.get()
        #expect(plainMetadata.count == 3)
        #expect(plainMetadata["public-data"]?.description == "visible")
        #expect(plainMetadata["private-data"]?.description == "<private>")
        #expect(plainMetadata["another-public"]?.description == "also-visible")
    }

    @Test("LogHandler default implementations without attributed support")
    func testLogHandlerDefaultImplementationsWithoutSupport() {
        // Create a minimal handler that doesn't implement attributed metadata support
        struct MinimalLogHandler: LogHandler {
            var logLevel: Logger.Level = .trace
            var metadata: Logger.Metadata = [:]

            func log(
                level: Logger.Level,
                message: Logger.Message,
                metadata: Logger.Metadata?,
                source: String,
                file: String,
                function: String,
                line: UInt
            ) {
                // Minimal implementation
            }

            subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
                get { metadata[metadataKey] }
                set { metadata[metadataKey] = newValue }
            }
        }

        var handler = MinimalLogHandler()

        // Test metadataProvider getter (should return nil)
        #expect(handler.metadataProvider == nil)

        // Test attributedMetadata getter (should return empty when no plain metadata exists)
        #expect(handler.attributedMetadata.isEmpty)

        // Test attributedMetadata setter (should convert to plain metadata)
        handler.attributedMetadata = [
            "key": Logger.AttributedMetadataValue(.string("value"), privacy: .public)
        ]
        // Should now be stored in plain metadata
        #expect(handler.attributedMetadata.count == 1)
        #expect(handler.attributedMetadata["key"]?.value.description == "value")
        #expect(handler.attributedMetadata["key"]?.attributes.privacy == .public)
        #expect(handler.metadata["key"]?.description == "value")

        // Test attributedMetadataKey subscript getter (should convert from plain metadata)
        #expect(handler[attributedMetadataKey: "key"]?.value.description == "value")
        #expect(handler[attributedMetadataKey: "key"]?.attributes.privacy == .public)

        // Test attributedMetadataKey subscript setter with private value (should redact in plain metadata)
        handler[attributedMetadataKey: "test"] = Logger.AttributedMetadataValue(.string("secret"), privacy: .private)
        #expect(handler[attributedMetadataKey: "test"]?.attributes.privacy == .public)  // Reading back gives public
        #expect(handler.metadata["test"]?.description == "<private>")  // Stored as redacted in plain metadata
    }

    @Test("Default attributed log method with nil metadata")
    func testDefaultAttributedLogMethodWithNilMetadata() {
        let recorder = FilterLogRecorder()
        let handler = FilterTestLogHandler(recorder: recorder)

        // Call attributed log method with nil attributedMetadata
        handler.log(
            level: .info,
            message: "Test message",
            attributedMetadata: nil,
            source: "test",
            file: "test.swift",
            function: "testFunc",
            line: 42
        )

        // Should pass nil to the plain log method
        #expect(recorder.receivedMetadata == nil)
    }

    @Test("MetadataProvider multiplex with empty provider")
    func testMetadataProviderMultiplexWithEmptyProvider() {
        // Test that multiplex handles providers that return empty metadata
        let emptyProvider = Logger.MetadataProvider { [:] }
        let nonEmptyProvider = Logger.MetadataProvider { ["key": "value"] }

        let multiplexed = Logger.MetadataProvider.multiplex([emptyProvider, nonEmptyProvider])
        #expect(multiplexed != nil)

        let metadata = multiplexed?.get()
        #expect(metadata != nil)
        #expect(metadata?.count == 1)
        #expect(metadata?["key"]?.description == "value")

        // Test with all empty providers
        let multiplexedEmpty = Logger.MetadataProvider.multiplex([emptyProvider, emptyProvider])
        #expect(multiplexedEmpty != nil)

        let emptyMetadata = multiplexedEmpty?.get()
        #expect(emptyMetadata != nil)
        #expect(emptyMetadata?.isEmpty == true)
    }

    @Test(
        "Logger convenience methods with attributedMetadata",
        arguments: [
            Logger.Level.trace,
            .debug,
            .info,
            .notice,
            .warning,
            .error,
            .critical,
        ]
    )
    func testLoggerConvenienceMethodsWithAttributedMetadata(level: Logger.Level) {
        let (stream, logger) = makeStreamLogger()
        var mutableLogger = logger
        mutableLogger.logLevel = .trace

        // Call the appropriate log method for the level
        mutableLogger.log(
            level: level,
            "\(level) message",
            attributedMetadata: [
                "public-\(level)": "\("\(level)-public", privacy: .public)",
                "private-\(level)": "\("\(level)-private", privacy: .private)",
            ]
        )

        #expect(stream.output.contains("\(level) message"))
        #expect(stream.output.contains("public-\(level)=\(level)-public"))
        #expect(stream.output.contains("private-\(level)=\(TestData.redactionMarker)"))
    }

    @Test(
        "Logger convenience methods with attributedMetadata and custom source",
        arguments: [
            (Logger.Level.trace, "custom-source"),
            (.info, "another-source"),
            (.error, "error-source"),
        ]
    )
    func testLoggerConvenienceMethodsWithAttributedMetadataAndSource(level: Logger.Level, source: String) {
        let (stream, logger) = makeStreamLogger()
        var mutableLogger = logger
        mutableLogger.logLevel = .trace

        // Test with source
        mutableLogger.log(
            level: level,
            "\(level) with source",
            attributedMetadata: ["key": Logger.AttributedMetadataValue(.string("value"), privacy: .public)],
            source: source
        )

        #expect(stream.output.contains("\(level) with source"))
        #expect(stream.output.contains("[\(source)]"))
    }

    @Test("AttributedMetadataValue CustomStringConvertible redacts private values")
    func testAttributedMetadataValueDescription() {
        // Test public value - should show actual value
        let publicValue = Logger.AttributedMetadataValue(.string("visible-data"), privacy: .public)
        #expect(publicValue.description == "visible-data")
        #expect("\(publicValue)" == "visible-data")

        // Test private value - should redact to the library's redaction marker
        let privateValue = Logger.AttributedMetadataValue(.string("secret-data"), privacy: .private)
        #expect(privateValue.description == Logger.AttributedMetadataValue.redactionMarker)
        #expect("\(privateValue)" == Logger.AttributedMetadataValue.redactionMarker)

        // Test with different value types
        let publicInt = Logger.AttributedMetadataValue(.stringConvertible(42), privacy: .public)
        #expect(publicInt.description == "42")

        let privateInt = Logger.AttributedMetadataValue(.stringConvertible(42), privacy: .private)
        #expect(privateInt.description == Logger.AttributedMetadataValue.redactionMarker)

        // Test in string interpolation
        let message = "User: \(publicValue), Password: \(privateValue)"
        #expect(message == "User: visible-data, Password: \(Logger.AttributedMetadataValue.redactionMarker)")
    }

    @Test("PrivacyLevel CustomStringConvertible")
    func testPrivacyLevelDescription() {
        #expect(Logger.PrivacyLevel.public.description == "public")
        #expect(Logger.PrivacyLevel.private.description == "private")
        #expect("\(Logger.PrivacyLevel.public)" == "public")
        #expect("\(Logger.PrivacyLevel.private)" == "private")
    }

    @Test("PrivacyLevel Codable conformance")
    func testPrivacyLevelCodable() throws {
        // Test encoding
        let publicLevel = Logger.PrivacyLevel.public
        let publicData = try JSONEncoder().encode(publicLevel)
        let publicString = String(data: publicData, encoding: .utf8)
        #expect(publicString == "\"public\"")

        let privateLevel = Logger.PrivacyLevel.private
        let privateData = try JSONEncoder().encode(privateLevel)
        let privateString = String(data: privateData, encoding: .utf8)
        #expect(privateString == "\"private\"")

        // Test decoding
        let decodedPublic = try JSONDecoder().decode(Logger.PrivacyLevel.self, from: publicData)
        #expect(decodedPublic == .public)

        let decodedPrivate = try JSONDecoder().decode(Logger.PrivacyLevel.self, from: privateData)
        #expect(decodedPrivate == .private)
    }

    @Test("PrivacyLevel raw value initialization")
    func testPrivacyLevelRawValue() {
        #expect(Logger.PrivacyLevel(rawValue: "public") == .public)
        #expect(Logger.PrivacyLevel(rawValue: "private") == .private)
        #expect(Logger.PrivacyLevel(rawValue: "invalid") == nil)
    }

    @Test("MetadataValueAttributes CustomStringConvertible")
    func testMetadataValueAttributesDescription() {
        let publicAttrs = Logger.MetadataValueAttributes(privacy: .public)
        #expect(publicAttrs.description == "privacy: public")
        #expect("\(publicAttrs)" == "privacy: public")

        let privateAttrs = Logger.MetadataValueAttributes(privacy: .private)
        #expect(privateAttrs.description == "privacy: private")
        #expect("\(privateAttrs)" == "privacy: private")
    }
}

// MARK: - Test Helpers

/// Test output stream for capturing log output
internal final class TestOutputStream: TextOutputStream, @unchecked Sendable {
    var output: String = ""

    func write(_ string: String) {
        // This is a test implementation, a real implementation would include locking
        self.output += string
    }
}

/// Recorder for privacy test log entries
internal final class PrivacyLogRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _messages:
        [(
            level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?,
            attributedMetadata: Logger.AttributedMetadata?
        )] = []

    func record(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        attributedMetadata: Logger.AttributedMetadata?
    ) {
        self.lock.withLock {
            self._messages.append(
                (level: level, message: message, metadata: metadata, attributedMetadata: attributedMetadata)
            )
        }
    }

    var messages:
        [(
            level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?,
            attributedMetadata: Logger.AttributedMetadata?
        )]
    {
        self.lock.withLock { self._messages }
    }
}

internal struct PrivacyTestLogHandler: LogHandler {
    var logLevel: Logger.Level = .trace
    var metadata: Logger.Metadata = [:]
    var metadataProvider: Logger.MetadataProvider?
    private let recorder: PrivacyLogRecorder

    var attributedMetadata = Logger.AttributedMetadata()

    init(recorder: PrivacyLogRecorder) {
        self.recorder = recorder
    }

    subscript(attributedMetadataKey key: String) -> Logger.AttributedMetadataValue? {
        get {
            self.attributedMetadata[key]
        }
        set {
            self.attributedMetadata[key] = newValue
        }
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        self.recorder.record(level: level, message: message, metadata: metadata, attributedMetadata: nil)
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        attributedMetadata: Logger.AttributedMetadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        // Merge handler metadata, provider metadata, and explicit attributed metadata
        var merged = Logger.AttributedMetadata()

        // Add handler metadata as public
        for (key, value) in self.metadata {
            merged[key] = Logger.AttributedMetadataValue(value, privacy: .public)
        }

        // Add metadata provider values as public
        if let provider = self.metadataProvider {
            for (key, value) in provider.get() {
                merged[key] = Logger.AttributedMetadataValue(value, privacy: .public)
            }
        }

        // Merge with explicit attributed metadata (takes precedence)
        if let attributedMetadata = attributedMetadata {
            for (key, value) in attributedMetadata {
                merged[key] = value
            }
        }

        self.recorder.record(
            level: level,
            message: message,
            metadata: nil,
            attributedMetadata: merged.isEmpty ? nil : merged
        )
    }

    subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get { metadata[metadataKey] }
        set { metadata[metadataKey] = newValue }
    }
}

/// Recorder for filter test log entries
internal final class FilterLogRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _receivedMetadata: Logger.Metadata?

    func record(metadata: Logger.Metadata?) {
        self.lock.withLock {
            self._receivedMetadata = metadata
        }
    }

    var receivedMetadata: Logger.Metadata? {
        self.lock.withLock { self._receivedMetadata }
    }
}

/// LogHandler that doesn't implement attributed method, relying on default implementation
internal struct FilterTestLogHandler: LogHandler {
    var logLevel: Logger.Level = .trace
    var metadata: Logger.Metadata = [:]
    var metadataProvider: Logger.MetadataProvider?
    private let recorder: FilterLogRecorder

    var attributedMetadata = Logger.AttributedMetadata()

    init(recorder: FilterLogRecorder) {
        self.recorder = recorder
    }

    subscript(attributedMetadataKey key: String) -> Logger.AttributedMetadataValue? {
        get {
            self.attributedMetadata[key]
        }
        set {
            self.attributedMetadata[key] = newValue
        }
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        self.recorder.record(metadata: metadata)
    }

    subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get { metadata[metadataKey] }
        set { metadata[metadataKey] = newValue }
    }
}
