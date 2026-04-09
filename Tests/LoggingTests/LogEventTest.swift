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

    // MARK: - Attributed metadata on LogEvent

    @Test func attributedMetadataReturnsNilWhenNone() {
        let event = LogEvent(
            level: .info,
            message: "hello",
            metadata: nil,
            source: nil,
            file: "M/F.swift",
            function: "f()",
            line: 1
        )
        #expect(event.metadata == nil)
        #expect(event.attributedMetadata == nil)
    }

    @Test func plainMetadataDoesNotEagerlyAllocateAttributed() {
        let event = LogEvent(
            level: .info,
            message: "hello",
            metadata: ["key": "value"],
            source: nil,
            file: "M/F.swift",
            function: "f()",
            line: 1
        )
        // Accessing plain metadata returns it directly
        #expect(event.metadata?["key"] == "value")

        // Internal storage should be .plain
        switch event._metadataStorage {
        case .plain:
            break  // expected
        default:
            Issue.record("Expected .plain storage but got something else")
        }
    }

    @Test func attributedMetadataInitStoresAttributed() {
        let attributed: Logger.AttributedMetadata = [
            "key": .init(.string("value"), attributes: .init())
        ]
        let event = LogEvent(
            level: .info,
            message: "hello",
            attributedMetadata: attributed,
            source: nil,
            file: "M/F.swift",
            function: "f()",
            line: 1
        )

        // Internal storage should be .attributed
        switch event._metadataStorage {
        case .attributed:
            break  // expected
        default:
            Issue.record("Expected .attributed storage but got something else")
        }

        // Accessing attributedMetadata returns it directly
        #expect(event.attributedMetadata?["key"]?.value == .string("value"))
    }

    @Test func plainMetadataConvertsToAttributedOnAccess() {
        let event = LogEvent(
            level: .info,
            message: "hello",
            metadata: ["key": "value"],
            source: nil,
            file: "M/F.swift",
            function: "f()",
            line: 1
        )

        // Accessing attributedMetadata wraps values with empty attributes
        let attributed = event.attributedMetadata
        #expect(attributed != nil)
        #expect(attributed?["key"]?.value == .string("value"))
        #expect(attributed?["key"]?.attributes == .init())

        // Internal storage should still be .plain (lazy, not mutated)
        switch event._metadataStorage {
        case .plain:
            break  // expected
        default:
            Issue.record("Expected .plain storage to remain unchanged")
        }
    }

    @Test func attributedMetadataConvertsToPlainOnAccess() {
        let attributed: Logger.AttributedMetadata = [
            "key": .init(.string("value"), attributes: .init())
        ]
        let event = LogEvent(
            level: .info,
            message: "hello",
            attributedMetadata: attributed,
            source: nil,
            file: "M/F.swift",
            function: "f()",
            line: 1
        )

        // Accessing metadata strips attributes
        let plain = event.metadata
        #expect(plain != nil)
        #expect(plain?["key"] == .string("value"))

        // Internal storage should still be .attributed (lazy, not mutated)
        switch event._metadataStorage {
        case .attributed:
            break  // expected
        default:
            Issue.record("Expected .attributed storage to remain unchanged")
        }
    }

    @Test func settingMetadataReplacesAttributedStorage() {
        var event = LogEvent(
            level: .info,
            message: "hello",
            attributedMetadata: ["key": .init(.string("value"), attributes: .init())],
            source: nil,
            file: "M/F.swift",
            function: "f()",
            line: 1
        )

        // Setting plain metadata replaces the storage
        event.metadata = ["new": "plain"]
        switch event._metadataStorage {
        case .plain:
            break  // expected
        default:
            Issue.record("Expected .plain storage after setting metadata")
        }
        #expect(event.metadata?["new"] == "plain")
        #expect(event.attributedMetadata?["new"]?.value == .string("plain"))
    }

    @Test func settingAttributedMetadataReplacesPlainStorage() {
        var event = LogEvent(
            level: .info,
            message: "hello",
            metadata: ["key": "value"],
            source: nil,
            file: "M/F.swift",
            function: "f()",
            line: 1
        )

        // Setting attributed metadata replaces the storage
        event.attributedMetadata = ["new": .init(.string("attributed"), attributes: .init())]
        switch event._metadataStorage {
        case .attributed:
            break  // expected
        default:
            Issue.record("Expected .attributed storage after setting attributedMetadata")
        }
        #expect(event.attributedMetadata?["new"]?.value == .string("attributed"))
        #expect(event.metadata?["new"] == .string("attributed"))
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
