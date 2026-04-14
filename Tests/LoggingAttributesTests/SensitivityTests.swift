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
import LoggingAttributes
import Testing

@testable import Logging

@Suite("Redaction Tests")
struct RedactionTests {

    // MARK: - Test Data Constants

    private enum TestData {
        static let userId = UUID(uuidString: "12345678-1234-5678-1234-567812345678")!
        static let action = "login"
        static let sessionId = UUID(uuidString: "87654321-4321-8765-4321-876543218765")!
        static let requestId = UUID(uuidString: "ABCDEF01-2345-6789-ABCD-EF0123456789")!
        static let redactionMarker = SensitivityAwareLogHandlerWrapper.redactionMarker
    }

    // MARK: - Test Fixtures

    private func makeRecorderLogger() -> (RedactionLogRecorder, Logger) {
        let recorder = RedactionLogRecorder()
        let handler = RedactionTestLogHandler(recorder: recorder)
        var logger = Logger(label: "test") { _ in handler }
        logger.logLevel = .trace
        return (recorder, logger)
    }

    private func makeStreamLogger(
        sensitivityBehavior: SensitivityAwareLogHandlerWrapper.SensitivityBehavior = .redact
    )
        -> (TestOutputStream, Logger)
    {
        let stream = TestOutputStream()
        let streamHandler = StreamLogHandler(label: "test", stream: stream, metadataProvider: nil)
        let handler = SensitivityAwareLogHandlerWrapper(
            wrapping: streamHandler,
            sensitivityBehavior: sensitivityBehavior
        )
        return (stream, Logger(label: "test") { _ in handler })
    }

    // MARK: - Tests

    @Test("Sensitivity enum properties")
    func testSensitivity() {
        #expect("\(Logger.Sensitivity.sensitive)" == "sensitive")
        #expect("\(Logger.Sensitivity.public)" == "public")
        #expect(Logger.Sensitivity.allCases.contains(.sensitive))
        #expect(Logger.Sensitivity.allCases.contains(.public))
    }

    @Test("MetadataValueAttributes initialization")
    func testMetadataValueAttributes() {
        let defaultAttrs = Logger.MetadataValueAttributes()
        #expect(defaultAttrs.sensitivity == nil)

        let publicAttrs = Logger.MetadataValueAttributes(sensitivity: .public)
        #expect(publicAttrs.sensitivity == .public)

        let redactAttrs = Logger.MetadataValueAttributes(sensitivity: .sensitive)
        #expect(redactAttrs.sensitivity == .sensitive)
    }

    @Test("AttributedMetadataValue initialization")
    func testAttributedMetadataValue() {
        let value = Logger.MetadataValue.string("test")
        let attributes = Logger.MetadataValueAttributes(sensitivity: .public)

        let attributed1 = Logger.AttributedMetadataValue(value, attributes: attributes)
        #expect(attributed1.value.description == "test")
        #expect(attributed1.attributes.sensitivity == .public)

        let attributed2 = Logger.AttributedMetadataValue(value, sensitivity: .sensitive)
        #expect(attributed2.value.description == "test")
        #expect(attributed2.attributes.sensitivity == .sensitive)
    }

    @Test("String interpolation API usage")
    func testStringInterpolationAPI() {
        // Test string interpolation as described in the proposal
        let metadata: Logger.AttributedMetadata = [
            "user.id": "\(TestData.userId, sensitivity: .sensitive)",
            "action": "\(TestData.action, sensitivity: .public)",
            "timestamp": "\("2024-01-01", sensitivity: .public)",
            "settings": .init(
                .dictionary(["theme": .string("dark"), "notifications": .string("enabled")]),
                sensitivity: .sensitive
            ),
            "features": .init(.array([.string("feature1"), .string("feature2")]), sensitivity: .public),
            "session.id": "\(TestData.sessionId, sensitivity: .sensitive)",
            "endpoint": "\("/api/v1/login", sensitivity: .public)",
            "source": "\("mobile-app", sensitivity: .public)",
        ]

        #expect(metadata.count == 8)
        #expect(metadata["user.id"]?.attributes.sensitivity == .sensitive)
        #expect(metadata["action"]?.attributes.sensitivity == .public)
        #expect(metadata["timestamp"]?.attributes.sensitivity == .public)
        #expect(metadata["settings"]?.attributes.sensitivity == .sensitive)
        #expect(metadata["features"]?.attributes.sensitivity == .public)
        #expect(metadata["session.id"]?.attributes.sensitivity == .sensitive)
        #expect(metadata["endpoint"]?.attributes.sensitivity == .public)
        #expect(metadata["source"]?.attributes.sensitivity == .public)
    }

    @Test("Attributed metadata logging")
    func testAttributedMetadataLogging() {
        let (recorder, logger) = makeRecorderLogger()

        let attributedMetadata: Logger.AttributedMetadata = [
            "user.id": "\(TestData.userId, sensitivity: .sensitive)",
            "action": "\(TestData.action, sensitivity: .public)",
        ]

        logger.log(level: .info, "User action", attributedMetadata: attributedMetadata)

        #expect(recorder.messages.count == 1)
        #expect(recorder.messages[0].level == .info)
        #expect(recorder.messages[0].message.description == "User action")
        #expect(recorder.messages[0].attributedMetadata != nil)
        #expect(recorder.messages[0].attributedMetadata?["user.id"]?.attributes.sensitivity == .sensitive)
        #expect(recorder.messages[0].attributedMetadata?["action"]?.attributes.sensitivity == .public)
    }

    @Test("Global plain metadata is merged with attributed metadata as .public")
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
                "request.id": "\(TestData.requestId, sensitivity: .public)",
                "user.id": "\("user-456", sensitivity: .sensitive)",
            ]
        )

        #expect(recorder.messages.count == 1)

        let finalMetadata = recorder.messages[0].attributedMetadata
        #expect(finalMetadata != nil)

        // Global metadata SHOULD be present in attributed logging, converted to .public
        #expect(finalMetadata?["service"]?.attributes.sensitivity == .public)
        #expect(finalMetadata?["service"]?.value.description == "auth-service")
        #expect(finalMetadata?["version"]?.attributes.sensitivity == .public)
        #expect(finalMetadata?["version"]?.value.description == "1.0")

        // Log-specific metadata should also be present with their specified sensitivity levels
        #expect(finalMetadata?["request.id"]?.attributes.sensitivity == .public)
        #expect(finalMetadata?["user.id"]?.attributes.sensitivity == .sensitive)
        #expect(finalMetadata?.count == 4)
    }

    @Test("SensitivityAwareLogHandlerWrapper redacts redacted metadata")
    func testSensitivityAwareLogHandlerWrapperRedaction() {
        let (stream, logger) = makeStreamLogger()

        logger.log(
            level: .info,
            "User action",
            attributedMetadata: [
                "user.id": "\(TestData.userId, sensitivity: .sensitive)",
                "action": "\(TestData.action, sensitivity: .public)",
                "session.id": "\(TestData.sessionId, sensitivity: .sensitive)",
            ]
        )

        // Check that redacted values are redacted as ***
        #expect(stream.output.contains("action=\(TestData.action)"))
        #expect(stream.output.contains("user.id=\(TestData.redactionMarker)"))
        #expect(stream.output.contains("session.id=\(TestData.redactionMarker)"))
        #expect(!stream.output.contains(TestData.userId.uuidString))
        #expect(!stream.output.contains(TestData.sessionId.uuidString))
    }

    @Test("SensitivityAwareLogHandlerWrapper logs redacted metadata when configured")
    func testSensitivityAwareLogHandlerWrapperLogsRedacted() {
        let (stream, logger) = makeStreamLogger(sensitivityBehavior: .log)

        logger.log(
            level: .info,
            "User action",
            attributedMetadata: [
                "user.id": "\(TestData.userId, sensitivity: .sensitive)",
                "action": "\(TestData.action, sensitivity: .public)",
            ]
        )

        // Check that redacted values are logged normally
        #expect(stream.output.contains("user.id=\(TestData.userId.uuidString)"))
        #expect(stream.output.contains("action=\(TestData.action)"))
        #expect(!stream.output.contains(TestData.redactionMarker))
    }

    @Test("SensitivityAwareLogHandlerWrapper factory pattern works")
    func testSensitivityAwareLogHandlerWrapperFactoryPattern() {
        // Test creating wrapper with default behavior
        let streamHandler1 = StreamLogHandler.standardOutput(label: "stdout-test")
        let wrapper1 = SensitivityAwareLogHandlerWrapper(wrapping: streamHandler1)
        #expect(wrapper1.logLevel == .info)
        #expect(wrapper1.sensitivityBehavior == .redact)

        // Test creating wrapper with custom behavior
        let streamHandler2 = StreamLogHandler.standardError(label: "stderr-test")
        let wrapper2 = SensitivityAwareLogHandlerWrapper(wrapping: streamHandler2, sensitivityBehavior: .log)
        #expect(wrapper2.logLevel == .info)
        #expect(wrapper2.sensitivityBehavior == .log)

        // Test with metadata provider
        let provider = Logger.MetadataProvider { ["env": "test"] }
        let streamHandler3 = StreamLogHandler.standardOutput(label: "test")
        var wrapper3 = SensitivityAwareLogHandlerWrapper(wrapping: streamHandler3)
        wrapper3.metadataProvider = provider
        #expect(wrapper3.metadataProvider != nil)
        #expect(wrapper3.sensitivityBehavior == .redact)
    }

    @Test("SensitivityAwareLogHandlerWrapper handles plain metadata")
    func testSensitivityAwareLogHandlerWrapperPlainMetadata() {
        let stream = TestOutputStream()

        let streamHandler = StreamLogHandler(label: "test", stream: stream, metadataProvider: nil)
        let handler = SensitivityAwareLogHandlerWrapper(wrapping: streamHandler)

        let logger = Logger(label: "test") { _ in handler }

        // Plain metadata should work normally
        logger.info("Plain message", metadata: ["key": "value", "count": "42"])

        #expect(stream.output.contains("key=value"))
        #expect(stream.output.contains("count=42"))
    }

    @Test("SensitivityAwareLogHandlerWrapper merges global metadata")
    func testSensitivityAwareLogHandlerWrapperGlobalMetadata() {
        let stream = TestOutputStream()
        let streamHandler = StreamLogHandler(label: "test", stream: stream, metadataProvider: nil)
        var handler = SensitivityAwareLogHandlerWrapper(wrapping: streamHandler, sensitivityBehavior: .redact)
        handler[metadataKey: "service"] = "auth"
        handler[metadataKey: "version"] = "1.0"

        let logger = Logger(label: "test") { _ in handler }

        logger.log(
            level: .info,
            "Request",
            attributedMetadata: [
                "user.id": "\(TestData.userId, sensitivity: .sensitive)",
                "request.id": "\(TestData.requestId, sensitivity: .public)",
            ]
        )

        // Global metadata should appear (treated as .public)
        #expect(stream.output.contains("service=auth"))
        #expect(stream.output.contains("version=1.0"))
        // .public attributed metadata should appear
        #expect(stream.output.contains("request.id=\(TestData.requestId.uuidString)"))
        // Redacted attributed metadata should be redacted
        #expect(stream.output.contains("user.id=\(TestData.redactionMarker)"))
        #expect(!stream.output.contains(TestData.userId.uuidString))
    }

    @Test("Handler sensitivityBehavior property")
    func testHandlerSensitivityBehavior() {
        let streamHandler = StreamLogHandler.standardOutput(label: "test")
        var handler = SensitivityAwareLogHandlerWrapper(wrapping: streamHandler)

        // Default should be .redact
        #expect(handler.sensitivityBehavior == .redact)

        // Should be able to change it
        handler.sensitivityBehavior = .log
        #expect(handler.sensitivityBehavior == .log)

        // Should support value semantics (COW via struct)
        var handler2 = handler
        handler2.sensitivityBehavior = .redact
        #expect(handler.sensitivityBehavior == .log)
        #expect(handler2.sensitivityBehavior == .redact)
    }

    @Test("Logger attributedMetadata property")
    func testLoggerAttributedMetadataProperty() {
        let (_, logger) = makeRecorderLogger()
        var mutableLogger = logger

        // Set attributed metadata on logger
        mutableLogger.attributedMetadata = [
            "user.id": "\(TestData.userId, sensitivity: .sensitive)",
            "action": "\(TestData.action, sensitivity: .public)",
        ]

        #expect(mutableLogger.attributedMetadata.count == 2)
        #expect(mutableLogger.attributedMetadata["user.id"]?.attributes.sensitivity == .sensitive)
        #expect(mutableLogger.attributedMetadata["action"]?.attributes.sensitivity == .public)
    }

    @Test("Logger attributedMetadata subscript")
    func testLoggerAttributedMetadataSubscript() {
        let (_, logger) = makeRecorderLogger()
        var mutableLogger = logger

        // Set attributed metadata via subscript
        mutableLogger[attributedMetadataKey: "user.id"] = "\(TestData.userId, sensitivity: .sensitive)"
        mutableLogger[attributedMetadataKey: "action"] = "\(TestData.action, sensitivity: .public)"

        #expect(mutableLogger[attributedMetadataKey: "user.id"]?.attributes.sensitivity == .sensitive)
        #expect(mutableLogger[attributedMetadataKey: "action"]?.attributes.sensitivity == .public)

        // Update attributed metadata
        let newUserId = "67890"
        mutableLogger[attributedMetadataKey: "user.id"] = "\(newUserId, sensitivity: .public)"
        #expect(mutableLogger[attributedMetadataKey: "user.id"]?.attributes.sensitivity == .public)
        #expect(mutableLogger[attributedMetadataKey: "user.id"]?.value.description == "67890")
    }

    @Test("LogHandler attributedMetadata property")
    func testLogHandlerAttributedMetadataProperty() {
        let streamHandler = StreamLogHandler.standardOutput(label: "test")
        var handler = SensitivityAwareLogHandlerWrapper(wrapping: streamHandler)

        let service = "auth"
        let version = "1.0"

        // Set attributed metadata on handler
        handler.attributedMetadata = [
            "service": "\(service, sensitivity: .public)",
            "version": "\(version, sensitivity: .public)",
        ]

        #expect(handler.attributedMetadata.count == 2)
        #expect(handler.attributedMetadata["service"]?.attributes.sensitivity == .public)
        #expect(handler.attributedMetadata["version"]?.attributes.sensitivity == .public)
    }

    @Test("LogHandler attributedMetadata subscript")
    func testLogHandlerAttributedMetadataSubscript() {
        let streamHandler = StreamLogHandler.standardOutput(label: "test")
        var handler = SensitivityAwareLogHandlerWrapper(wrapping: streamHandler)

        let service = "auth"
        let version = "1.0"

        // Set attributed metadata via subscript
        handler[attributedMetadataKey: "service"] = "\(service, sensitivity: .public)"
        handler[attributedMetadataKey: "version"] = "\(version, sensitivity: .sensitive)"

        #expect(handler[attributedMetadataKey: "service"]?.attributes.sensitivity == .public)
        #expect(handler[attributedMetadataKey: "version"]?.attributes.sensitivity == .sensitive)

        // Remove attributed metadata
        handler[attributedMetadataKey: "version"] = nil
        #expect(handler[attributedMetadataKey: "version"] == nil)
        #expect(handler.attributedMetadata.count == 1)
    }

    @Test("Logger value semantics for attributed metadata")
    func testLoggerValueSemanticsAttributedMetadata() {
        let recorder = RedactionLogRecorder()
        var logger1 = Logger(label: "test") { _ in RedactionTestLogHandler(recorder: recorder) }

        let value1 = "value1"
        let value2 = "value2"

        logger1[attributedMetadataKey: "key1"] = Logger.AttributedMetadataValue(
            .string(value1),
            sensitivity: .sensitive
        )

        var logger2 = logger1
        logger2[attributedMetadataKey: "key2"] = Logger.AttributedMetadataValue(.string(value2), sensitivity: .public)

        // logger1 should not have key2
        #expect(logger1[attributedMetadataKey: "key1"]?.value.description == "value1")
        #expect(logger1[attributedMetadataKey: "key2"] == nil)

        // logger2 should have both
        #expect(logger2[attributedMetadataKey: "key1"]?.value.description == "value1")
        #expect(logger2[attributedMetadataKey: "key2"]?.value.description == "value2")
    }

    @Test("String interpolation with sensitivity parameter")
    func testStringInterpolationWithSensitivity() {
        // Test interpolation with explicit sensitivity
        let redactedValue: Logger.AttributedMetadataValue = "\(TestData.userId, sensitivity: .sensitive)"
        #expect(redactedValue.value.description == TestData.userId.uuidString)
        #expect(redactedValue.attributes.sensitivity == .sensitive)

        let publicValue: Logger.AttributedMetadataValue = "\(TestData.action, sensitivity: .public)"
        #expect(publicValue.value.description == TestData.action)
        #expect(publicValue.attributes.sensitivity == .public)

        // Test multiple interpolations (strictest sensitivity wins)
        let mixedRedactedFirst: Logger.AttributedMetadataValue =
            "User \(TestData.userId, sensitivity: .sensitive) performed \(TestData.action, sensitivity: .public)"
        #expect(
            mixedRedactedFirst.value.description == "User \(TestData.userId.uuidString) performed \(TestData.action)"
        )
        #expect(mixedRedactedFirst.attributes.sensitivity == .sensitive)

        // Test multiple interpolations (strictest sensitivity wins)
        let mixedPublicFirst: Logger.AttributedMetadataValue =
            "User \(TestData.userId, sensitivity: .public) performed \(TestData.action, sensitivity: .sensitive)"
        #expect(mixedPublicFirst.value.description == "User \(TestData.userId.uuidString) performed \(TestData.action)")
        #expect(mixedPublicFirst.attributes.sensitivity == .sensitive)

        // Test string literal (defaults to empty attributes, no sensitivity)
        let literal: Logger.AttributedMetadataValue = "literal value"
        #expect(literal.value.description == "literal value")
        #expect(literal.attributes.sensitivity == nil)

        // Test interpolation without sensitivity parameter (using attributes closure that sets nothing)
        let defaultSensitivity: Logger.AttributedMetadataValue = "\(TestData.userId, attributes: { _ in })"
        #expect(defaultSensitivity.value.description == TestData.userId.uuidString)
        #expect(defaultSensitivity.attributes.sensitivity == nil)
    }

    @Test("String interpolation in logging")
    func testStringInterpolationInLogging() {
        let (recorder, logger) = makeRecorderLogger()

        logger.log(
            level: .info,
            "User action",
            attributedMetadata: [
                "user.id": "\(TestData.userId, sensitivity: .sensitive)",
                "action": "\(TestData.action, sensitivity: .public)",
                "session": "sess-\(TestData.userId, sensitivity: .sensitive)",
            ]
        )

        #expect(recorder.messages.count == 1)
        let metadata = recorder.messages[0].attributedMetadata
        #expect(metadata != nil)
        #expect(metadata?["user.id"]?.attributes.sensitivity == .sensitive)
        #expect(metadata?["user.id"]?.value.description == TestData.userId.uuidString)
        #expect(metadata?["action"]?.attributes.sensitivity == .public)
        #expect(metadata?["action"]?.value.description == TestData.action)
        #expect(metadata?["session"]?.attributes.sensitivity == .sensitive)
        #expect(metadata?["session"]?.value.description == "sess-\(TestData.userId.uuidString)")
    }

    @Test("MetadataProvider plain and attributed creation and access")
    func testMetadataProviderPlainAndAttributed() {
        // Plain provider: get() returns values, getAttributed() wraps with empty attributes
        let plainProvider = Logger.MetadataProvider {
            ["service": "test-service", "version": "1.0"]
        }

        let plainMetadata = plainProvider.get()
        #expect(plainMetadata["service"]?.description == "test-service")
        #expect(plainMetadata["version"]?.description == "1.0")

        let plainAttributed = plainProvider.getAttributed()
        #expect(plainAttributed.count == 2)
        #expect(plainAttributed["service"]?.value.description == "test-service")
        #expect(plainAttributed["service"]?.attributes.sensitivity == nil)

        // Attributed provider: getAttributed() returns full metadata, get() strips attributes
        let attributedProvider = Logger.MetadataProvider {
            [
                "public-key": "\("public-value", sensitivity: .public)",
                "private-key": "\("private-value", sensitivity: .sensitive)",
            ]
        }

        let attributedMetadata = attributedProvider.getAttributed()
        #expect(attributedMetadata["public-key"]?.attributes.sensitivity == .public)
        #expect(attributedMetadata["private-key"]?.attributes.sensitivity == .sensitive)

        let strippedMetadata = attributedProvider.get()
        #expect(strippedMetadata.count == 2)
        #expect(strippedMetadata["public-key"]?.description == "public-value")
        #expect(strippedMetadata["private-key"]?.description == "private-value")
    }

    @Test("LogHandler default implementations without attributed support")
    func testLogHandlerDefaultImplementationsWithoutSupport() {
        // Create a minimal handler that doesn't implement attributed metadata support
        struct MinimalLogHandler: LogHandler {
            var logLevel: Logger.Level = .trace
            var metadata: Logger.Metadata = [:]

            func log(event: LogEvent) {
                // Minimal implementation — reads plain metadata regardless of how event was created
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

        // Test attributedMetadata setter (should strip attributes and store raw value)
        handler.attributedMetadata = [
            "key": Logger.AttributedMetadataValue(.string("value"), sensitivity: .public)
        ]
        // Should now be stored in plain metadata
        #expect(handler.attributedMetadata.count == 1)
        #expect(handler.attributedMetadata["key"]?.value.description == "value")
        // Default returns empty attributes (no sensitivity knowledge in core)
        #expect(handler.attributedMetadata["key"]?.attributes.sensitivity == nil)
        #expect(handler.metadata["key"]?.description == "value")

        // Test attributedMetadataKey subscript getter (returns empty attributes)
        #expect(handler[attributedMetadataKey: "key"]?.value.description == "value")
        #expect(handler[attributedMetadataKey: "key"]?.attributes.sensitivity == nil)

        // Test attributedMetadataKey subscript setter with redacted value (strips attributes, stores raw value)
        handler[attributedMetadataKey: "test"] = Logger.AttributedMetadataValue(
            .string("secret"),
            sensitivity: .sensitive
        )
        // Reading back gives empty attributes
        #expect(handler[attributedMetadataKey: "test"]?.attributes.sensitivity == nil)

        // Stored as raw value in plain metadata
        #expect(handler.metadata["test"]?.description == "secret")
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

    @Test("MetadataProvider multiplex with attributed providers")
    func testMetadataProviderMultiplexWithAttributedProviders() {
        let plainProvider = Logger.MetadataProvider {
            ["env": "production", "host": "server-1"]
        }
        let attributedProvider = Logger.MetadataProvider {
            [
                "user-id": "\("u-123", sensitivity: .sensitive)",
                "request-id": "\("r-456", sensitivity: .public)",
            ]
        }

        // Multiplex of plain + attributed — should produce an attributed provider
        let multiplexed = Logger.MetadataProvider.multiplex([plainProvider, attributedProvider])
        #expect(multiplexed != nil)

        // getAttributed() should return all metadata with attributes preserved
        let attributed = multiplexed!.getAttributed()
        #expect(attributed.count == 4)
        // Plain provider values should have empty attributes
        #expect(attributed["env"]?.value.description == "production")
        #expect(attributed["env"]?.attributes.sensitivity == nil)
        #expect(attributed["host"]?.value.description == "server-1")
        // Attributed provider values should keep their sensitivity
        #expect(attributed["user-id"]?.attributes.sensitivity == .sensitive)
        #expect(attributed["request-id"]?.attributes.sensitivity == .public)

        // get() should strip all attributes
        let plain = multiplexed!.get()
        #expect(plain.count == 4)
        #expect(plain["env"]?.description == "production")
        #expect(plain["user-id"]?.description == "u-123")
    }

    @Test("MetadataProvider multiplex attributed last-writer-wins")
    func testMetadataProviderMultiplexAttributedLastWriterWins() {
        let provider1 = Logger.MetadataProvider {
            [
                "key": "\("from-first", sensitivity: .public)"
            ]
        }
        let provider2 = Logger.MetadataProvider {
            [
                "key": "\("from-second", sensitivity: .sensitive)"
            ]
        }

        let multiplexed = Logger.MetadataProvider.multiplex([provider1, provider2])!
        let attributed = multiplexed.getAttributed()

        // Last provider wins
        #expect(attributed["key"]?.value.description == "from-second")
        #expect(attributed["key"]?.attributes.sensitivity == .sensitive)
    }

    @Test("MetadataProvider multiplex attributed with empty attributed provider")
    func testMetadataProviderMultiplexAttributedWithEmptyProvider() {
        let emptyAttributed = Logger.MetadataProvider {
            Logger.AttributedMetadata()
        }
        let plainProvider = Logger.MetadataProvider {
            ["key": "value"]
        }

        // Even with one empty attributed provider, the multiplex should be attributed
        let multiplexed = Logger.MetadataProvider.multiplex([emptyAttributed, plainProvider])!
        let attributed = multiplexed.getAttributed()
        #expect(attributed.count == 1)
        #expect(attributed["key"]?.value.description == "value")
        #expect(attributed["key"]?.attributes.sensitivity == nil)
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
                "public-\(level)": "\("\(level)-public", sensitivity: .public)",
                "private-\(level)": "\("\(level)-private", sensitivity: .sensitive)",
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
            attributedMetadata: ["key": Logger.AttributedMetadataValue(.string("value"), sensitivity: .public)],
            source: source
        )

        #expect(stream.output.contains("\(level) with source"))
        #expect(stream.output.contains("[\(source)]"))
    }

    @Test("AttributedMetadataValue CustomStringConvertible always shows raw values")
    func testAttributedMetadataValueDescription() {
        // .public value - should show actual value
        let publicValue = Logger.AttributedMetadataValue(.string("visible-data"), sensitivity: .public)
        #expect(publicValue.description == "visible-data")

        // .sensitive value - core description always shows raw value (no redaction knowledge)
        let redactedValue = Logger.AttributedMetadataValue(.string("secret-data"), sensitivity: .sensitive)
        #expect(redactedValue.description == "secret-data")

        // Different value types
        let publicInt = Logger.AttributedMetadataValue(.stringConvertible(42), sensitivity: .public)
        #expect(publicInt.description == "42")

        let redactedInt = Logger.AttributedMetadataValue(.stringConvertible(42), sensitivity: .sensitive)
        #expect(redactedInt.description == "42")
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

/// Recorder for redaction test log entries
internal final class RedactionLogRecorder: @unchecked Sendable {
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

internal struct RedactionTestLogHandler: LogHandler {
    var logLevel: Logger.Level = .trace
    var metadata: Logger.Metadata = [:]
    var metadataProvider: Logger.MetadataProvider?
    private let recorder: RedactionLogRecorder

    var attributedMetadata = Logger.AttributedMetadata()

    init(recorder: RedactionLogRecorder) {
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

    func log(event: LogEvent) {
        // Merge handler metadata, provider metadata, and event attributed metadata
        var merged = Logger.AttributedMetadata()

        // Add handler metadata as .public
        for (key, value) in self.metadata {
            merged[key] = Logger.AttributedMetadataValue(value, sensitivity: .public)
        }

        // Add metadata provider values as .public
        if let provider = self.metadataProvider {
            for (key, value) in provider.get() {
                merged[key] = Logger.AttributedMetadataValue(value, sensitivity: .public)
            }
        }

        // Merge with event's attributed metadata (takes precedence)
        if let eventAttributed = event.attributedMetadata {
            for (key, value) in eventAttributed {
                merged[key] = value
            }
        }

        self.recorder.record(
            level: event.level,
            message: event.message,
            metadata: event.metadata,
            attributedMetadata: merged.isEmpty ? nil : merged
        )
    }

    subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get { metadata[metadataKey] }
        set { metadata[metadataKey] = newValue }
    }
}
