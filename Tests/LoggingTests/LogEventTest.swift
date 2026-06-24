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

import Testing
import Foundation

@testable import Logging

struct LogEventTest {

    // MARK: - Lazy source computation

    @Test func sourceIsDerivedFromFileWhenNotProvided() {
        let event = LogEvent(
            level: .info,
            message: "hello",
            metadata: nil,
            source: nil,
            file: "MyModule/MyFile.swift",
            function: "f()",
            line: 1
        )
        #expect(event.source == "MyModule")
    }

    @Test func sourceUsesExplicitValueWhenProvided() {
        let event = LogEvent(
            level: .info,
            message: "hello",
            metadata: nil,
            source: "ExplicitSource",
            file: "MyModule/MyFile.swift",
            function: "f()",
            line: 1
        )
        #expect(event.source == "ExplicitSource")
    }

    @Test func sourceSetterOverridesLazyValue() {
        var event = LogEvent(
            level: .info,
            message: "hello",
            metadata: nil,
            source: nil,
            file: "MyModule/MyFile.swift",
            function: "f()",
            line: 1
        )
        #expect(event.source == "MyModule")

        event.source = "OverriddenSource"
        #expect(event.source == "OverriddenSource")
    }

    @Test func sourceLazyDerivationDoesNotStoreComputedValue() {
        let event = LogEvent(
            level: .info,
            message: "hello",
            metadata: nil,
            source: nil,
            file: "MyModule/MyFile.swift",
            function: "f()",
            line: 1
        )
        // Internal _source should be nil when no explicit source was provided.
        #expect(event._source == nil)
        // Accessing source derives it from file but does not mutate _source (it's a computed get).
        _ = event.source
        #expect(event._source == nil)
    }

    @Test func metadataSetterStoresThroughComputedProperty() {
        var event = LogEvent(
            level: .info,
            message: "hello",
            metadata: nil,
            source: nil,
            file: "M/F.swift",
            function: "f()",
            line: 1
        )
        #expect(event.metadata == nil)

        event.metadata = ["key": "value"]
        #expect(event.metadata?["key"] == "value")

        event.metadata = nil
        #expect(event.metadata == nil)
    }

    // MARK: - Attributes on metadata values

    @Test func metadataValueCarriesAttributesThroughStringInterpolation() {
        enum TestAttr: Int64, Logger.MetadataValueAttributes.Attribute {
            case flagged = 1
        }

        let value: Logger.MetadataValue = "\("secret", attributes: { $0[TestAttr.self] = .flagged })"
        #expect(value.attributes[TestAttr.self] == .flagged)
        #expect(value.description == "secret")
    }

    @Test func metadataValueWithoutAttributesProducesString() {
        let value: Logger.MetadataValue = "\("plain")"
        #expect(value.attributes == Logger.MetadataValueAttributes())

        if case .string(let s) = value {
            #expect(s == "plain")
        } else {
            Issue.record("Expected .string case for non-attributed interpolation")
        }
    }

    @Test func metadataValueAttributesAreEmptyForPlainValues() {
        let values: [Logger.MetadataValue] = [
            .string("test"),
            .stringConvertible(42),
            .array(["a", "b"]),
            .dictionary(["k": "v"]),
        ]
        for value in values {
            #expect(value.attributes == Logger.MetadataValueAttributes())
        }
    }

    @Test func metadataValuesWithAttributesFlowThroughLogEvent() {
        enum TestAttr: Int64, Logger.MetadataValueAttributes.Attribute {
            case flagged = 1
        }

        let event = LogEvent(
            level: .info,
            message: "test",
            error: nil,
            metadata: [
                "secret": "\("value", attributes: { $0[TestAttr.self] = .flagged })",
                "plain": "no-attrs",
            ],
            source: nil,
            file: "M/F.swift",
            function: "f()",
            line: 1
        )

        #expect(event.metadata?["secret"]?.attributes[TestAttr.self] == .flagged)
        #expect(event.metadata?["secret"]?.description == "value")
        #expect(event.metadata?["plain"]?.attributes[TestAttr.self] == nil)
    }

    @Test func loggerDerivedSourceMatchesModuleName() {
        let recorder = Recorder()
        let handler = LogEventHandler(recorder: recorder)
        var logger = Logger(label: "test", handler)
        logger.logLevel = .trace

        // Log without explicit source — source should be derived from #fileID.
        logger.info("derived source test")

        let entries = recorder.entries
        #expect(entries.count == 1)
        #expect(entries[0].source == "LoggingTests")
    }

    // MARK: - Default log(event:) forwarding to deprecated flat-parameter method

    @available(*, deprecated, message: "Testing deprecated functionality")
    @Test func defaultLogEventForwardsAllFieldsIncludingSourceLocation() {
        let recorder = Recorder()
        let handler = FlatParametersHandler(recorder: recorder)
        var logger = Logger(label: "test", handler)
        logger.logLevel = .trace

        logger.warning("location test")
        let line = UInt(#line - 1)

        let entries = recorder.entries
        #expect(entries.count == 1)
        #expect(entries[0].level == .warning)
        #expect(entries[0].message == "location test")
        #expect(entries[0].file.hasSuffix("LogEventTest.swift"))
        #expect(entries[0].function.contains("defaultLogEventForwardsAllFieldsIncludingSourceLocation"))
        #expect(entries[0].line == line)
    }
}

// MARK: - Test Helpers

/// A handler that implements `log(event:)` directly and records entries.
private struct LogEventHandler: LogHandler {
    let recorder: Recorder
    var logLevel: Logger.Level = .trace
    var metadata: Logger.Metadata = [:]
    var metadataProvider: Logger.MetadataProvider?

    func log(event: LogEvent) {
        self.recorder.record(level: event.level, metadata: event.metadata, message: event.message, source: event.source)
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.metadata[key] }
        set { self.metadata[key] = newValue }
    }
}

/// A handler that only implements the deprecated flat-parameter method, relying on the
/// default `log(event:)` forwarding bridge.
@available(*, deprecated, message: "Testing deprecated functionality")
private struct FlatParametersHandler: LogHandler {
    let recorder: Recorder
    var logLevel: Logger.Level = .trace
    var metadata: Logger.Metadata = [:]
    var metadataProvider: Logger.MetadataProvider?

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        self.recorder.record(
            level: level,
            metadata: metadata,
            message: message,
            source: source,
            file: file,
            function: function,
            line: line
        )
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.metadata[key] }
        set { self.metadata[key] = newValue }
    }
}
