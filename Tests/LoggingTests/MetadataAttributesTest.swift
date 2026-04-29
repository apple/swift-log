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

import Testing

@testable import Logging

// MARK: - Test Attribute Keys

enum AttrA: Int64, Logger.MetadataValueAttributes.Attribute {
    case a1 = 1
    case a2 = 2
}

enum AttrB: Int64, Logger.MetadataValueAttributes.Attribute {
    case b1 = 1
    case b2 = 2
}

enum AttrC: Int64, Logger.MetadataValueAttributes.Attribute {
    case c1 = 1
    case c2 = 2
}

enum AttrD: Int64, Logger.MetadataValueAttributes.Attribute {
    case d1 = 1
    case d2 = 2
}

enum AttrE: Int64, Logger.MetadataValueAttributes.Attribute {
    case e1 = 1
    case e2 = 2
}

// MARK: - Tests

@Suite("MetadataValueAttributes Tests")
struct MetadataAttributesTests {

    @Test("Empty attributes")
    func testEmpty() {
        let attrs = Logger.MetadataValueAttributes()
        #expect(attrs[AttrA.self] == nil)
        #expect(attrs[AttrB.self] == nil)
    }

    @Test("Set and get single attribute (inline)")
    func testSingleInline() {
        var attrs = Logger.MetadataValueAttributes()
        attrs[AttrA.self] = .a1
        #expect(attrs[AttrA.self] == .a1)
    }

    @Test("Set and get multiple attributes")
    func testMultipleAttributes() {
        var attrs = Logger.MetadataValueAttributes()
        attrs[AttrA.self] = .a1
        attrs[AttrB.self] = .b2
        attrs[AttrC.self] = .c1

        #expect(attrs[AttrA.self] == .a1)
        #expect(attrs[AttrB.self] == .b2)
        #expect(attrs[AttrC.self] == .c1)
    }

    @Test("Update existing attribute")
    func testUpdate() {
        var attrs = Logger.MetadataValueAttributes()
        attrs[AttrA.self] = .a1
        #expect(attrs[AttrA.self] == .a1)

        attrs[AttrA.self] = .a2
        #expect(attrs[AttrA.self] == .a2)
    }

    @Test("Remove inline attribute")
    func testRemoveInline() {
        var attrs = Logger.MetadataValueAttributes()
        attrs[AttrA.self] = .a1

        attrs[AttrA.self] = nil
        #expect(attrs[AttrA.self] == nil)
    }

    @Test("Remove overflow attribute")
    func testRemoveOverflow() {
        var attrs = Logger.MetadataValueAttributes()
        attrs[AttrA.self] = .a1
        attrs[AttrB.self] = .b1
        attrs[AttrC.self] = .c1

        attrs[AttrB.self] = nil
        #expect(attrs[AttrA.self] == .a1)
        #expect(attrs[AttrB.self] == nil)
        #expect(attrs[AttrC.self] == .c1)
    }

    @Test("Remove inline promotes from overflow")
    func testRemoveInlinePromotesOverflow() {
        var attrs = Logger.MetadataValueAttributes()
        attrs[AttrA.self] = .a1
        attrs[AttrB.self] = .b1  // overflow

        // Remove inline — overflow entry should be promoted
        attrs[AttrA.self] = nil

        #expect(attrs[AttrA.self] == nil)
        #expect(attrs[AttrB.self] == .b1)
    }

    @Test("Five attributes")
    func testFiveAttributes() {
        var attrs = Logger.MetadataValueAttributes()
        attrs[AttrA.self] = .a1
        attrs[AttrB.self] = .b1
        attrs[AttrC.self] = .c1
        attrs[AttrD.self] = .d1
        attrs[AttrE.self] = .e1

        #expect(attrs[AttrA.self] == .a1)
        #expect(attrs[AttrB.self] == .b1)
        #expect(attrs[AttrC.self] == .c1)
        #expect(attrs[AttrD.self] == .d1)
        #expect(attrs[AttrE.self] == .e1)
    }

    @Test("Update overflow attribute")
    func testUpdateOverflow() {
        var attrs = Logger.MetadataValueAttributes()
        attrs[AttrA.self] = .a1
        attrs[AttrB.self] = .b1

        attrs[AttrB.self] = .b2
        #expect(attrs[AttrB.self] == .b2)
        #expect(attrs[AttrA.self] == .a1)
    }

    @Test("Equality with same content")
    func testEquality() {
        var attrs1 = Logger.MetadataValueAttributes()
        attrs1[AttrA.self] = .a1
        attrs1[AttrB.self] = .b1

        var attrs2 = Logger.MetadataValueAttributes()
        attrs2[AttrA.self] = .a1
        attrs2[AttrB.self] = .b1

        #expect(attrs1 == attrs2)

        attrs2[AttrB.self] = .b2
        #expect(attrs1 != attrs2)
    }

    @Test("Equality is order-independent")
    func testOrderIndependentEquality() {
        var attrs1 = Logger.MetadataValueAttributes()
        attrs1[AttrA.self] = .a1
        attrs1[AttrB.self] = .b1
        attrs1[AttrC.self] = .c1

        var attrs2 = Logger.MetadataValueAttributes()
        attrs2[AttrC.self] = .c1
        attrs2[AttrA.self] = .a1
        attrs2[AttrB.self] = .b1

        #expect(attrs1 == attrs2)
    }

    @Test("Setting nil on non-existent attribute is no-op")
    func testSetNilNonExistent() {
        var attrs = Logger.MetadataValueAttributes()
        attrs[AttrA.self] = nil
        #expect(attrs[AttrA.self] == nil)

        attrs[AttrB.self] = .b1
        attrs[AttrA.self] = nil
        #expect(attrs[AttrA.self] == nil)
        #expect(attrs[AttrB.self] == .b1)
    }

    // MARK: - MetadataValue.attributed factory

    @Test("Create attributed value with .attributed factory")
    func testAttributedFactory() {
        let value: Logger.MetadataValue = .attributed("hello", attributes: [AttrA.a1])
        #expect(value.description == "hello")
        #expect(value.attributes[AttrA.self] == .a1)
    }

    @Test("Attributed factory with multiple attributes")
    func testAttributedFactoryMultipleAttributes() {
        let value: Logger.MetadataValue = .attributed("test", attributes: [AttrA.a1, AttrB.b2])
        #expect(value.description == "test")
        #expect(value.attributes[AttrA.self] == .a1)
        #expect(value.attributes[AttrB.self] == .b2)
    }

    @Test("Attributed factory with empty attributes")
    func testAttributedFactoryEmptyAttributes() {
        let value: Logger.MetadataValue = .attributed("plain", attributes: .init())
        #expect(value.description == "plain")
        #expect(value.attributes[AttrA.self] == nil)
    }

    @Test("Attributed factory produces same result as string interpolation")
    func testAttributedFactoryMatchesStringInterpolation() {
        let factory: Logger.MetadataValue = .attributed("42", attributes: [AttrA.a1])
        let interpolated: Logger.MetadataValue = "\(42, attributes: [AttrA.a1])"
        #expect(factory.description == interpolated.description)
        #expect(factory.attributes == interpolated.attributes)
    }

    // MARK: - Array literal construction

    @Test("Array literal with single attribute")
    func testArrayLiteralSingle() {
        let attrs: Logger.MetadataValueAttributes = [AttrA.a1]
        #expect(attrs[AttrA.self] == .a1)
    }

    @Test("Array literal with multiple attributes")
    func testArrayLiteralMultiple() {
        let attrs: Logger.MetadataValueAttributes = [AttrA.a1, AttrB.b2, AttrC.c1]
        #expect(attrs[AttrA.self] == .a1)
        #expect(attrs[AttrB.self] == .b2)
        #expect(attrs[AttrC.self] == .c1)
    }

    @Test("Array literal equals builder closure")
    func testArrayLiteralEqualsBuilder() {
        let fromLiteral: Logger.MetadataValueAttributes = [AttrA.a1, AttrB.b2]
        let fromBuilder = Logger.MetadataValueAttributes {
            $0[AttrA.self] = .a1
            $0[AttrB.self] = .b2
        }
        #expect(fromLiteral == fromBuilder)
    }

    @Test("Array literal with duplicate key uses last value")
    func testArrayLiteralDuplicateKey() {
        let attrs: Logger.MetadataValueAttributes = [AttrA.a1, AttrA.a2]
        #expect(attrs[AttrA.self] == .a2)
    }

    // MARK: - MetadataValue.attributes setter

    @Test("Set attributes on .string value")
    func testSetAttributesOnString() {
        var value: Logger.MetadataValue = "hello"
        #expect(value.attributes[AttrA.self] == nil)

        value.attributes = [AttrA.a1]

        #expect(value.description == "hello")
        #expect(value.attributes[AttrA.self] == .a1)
    }

    @Test("Set attributes replaces existing attributes")
    func testSetAttributesReplacesExisting() {
        var value: Logger.MetadataValue = .attributed("test", attributes: [AttrA.a1])
        #expect(value.attributes[AttrA.self] == .a1)

        let newAttrs: Logger.MetadataValueAttributes = [AttrB.b2]
        value.attributes = newAttrs

        #expect(value.description == "test")
        #expect(value.attributes[AttrA.self] == nil)
        #expect(value.attributes[AttrB.self] == .b2)
    }

    // MARK: - Intermediate handler modifies attributes

    @Test("Intermediate handler adds attributes before forwarding")
    func testIntermediateHandlerAddsAttributes() {
        let recorder = AttributeRecorder()
        let inner = AttributeRecordingHandler(recorder: recorder)
        let enriching = AttributeEnrichingHandler(wrapping: inner)

        var logger = Logger(label: "test") { _ in enriching }
        logger.logLevel = .trace

        logger.info(
            "event",
            metadata: [
                "tagged": .attributed(42, attributes: [AttrA.a1]),
                "plain": "no-attrs",
            ]
        )

        #expect(recorder.messages.count == 1)
        let metadata = recorder.messages[0]

        // The enriching handler should have added AttrB to all values
        #expect(metadata["tagged"]?.attributes[AttrA.self] == .a1)
        #expect(metadata["tagged"]?.attributes[AttrB.self] == .b1)
        #expect(metadata["plain"]?.attributes[AttrB.self] == .b1)
    }

    @Test("Intermediate handler replaces attributes before forwarding")
    func testIntermediateHandlerReplacesAttributes() {
        let recorder = AttributeRecorder()
        let inner = AttributeRecordingHandler(recorder: recorder)
        let stripping = AttributeStrippingHandler(wrapping: inner)

        var logger = Logger(label: "test") { _ in stripping }
        logger.logLevel = .trace

        logger.info(
            "event",
            metadata: [
                "tagged": .attributed(42, attributes: [AttrA.a1])
            ]
        )

        #expect(recorder.messages.count == 1)
        let metadata = recorder.messages[0]

        // The stripping handler should have removed all attributes
        #expect(metadata["tagged"]?.attributes[AttrA.self] == nil)
        #expect(metadata["tagged"]?.description == "42")
    }
}

// MARK: - Test Helpers for intermediate handler tests

private final class AttributeRecorder: @unchecked Sendable {
    private let lock = Lock()
    private var _messages: [Logger.Metadata] = []

    func record(metadata: Logger.Metadata) {
        self.lock.withLock { self._messages.append(metadata) }
    }

    var messages: [Logger.Metadata] {
        self.lock.withLock { self._messages }
    }
}

private struct AttributeRecordingHandler: LogHandler {
    var logLevel: Logger.Level = .trace
    var metadata = Logger.Metadata()
    var metadataProvider: Logger.MetadataProvider?
    private let recorder: AttributeRecorder

    init(recorder: AttributeRecorder) {
        self.recorder = recorder
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.metadata[key] }
        set { self.metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        var merged = self.metadata
        if let eventMetadata = event.metadata {
            merged.merge(eventMetadata, uniquingKeysWith: { _, rhs in rhs })
        }
        self.recorder.record(metadata: merged)
    }
}

/// Intermediate handler that enriches all metadata values with AttrB before forwarding.
private struct AttributeEnrichingHandler: LogHandler {
    var logLevel: Logger.Level {
        get { self.inner.logLevel }
        set { self.inner.logLevel = newValue }
    }

    var metadata: Logger.Metadata {
        get { self.inner.metadata }
        set { self.inner.metadata = newValue }
    }

    var metadataProvider: Logger.MetadataProvider? {
        get { self.inner.metadataProvider }
        set { self.inner.metadataProvider = newValue }
    }

    private var inner: any LogHandler

    init(wrapping inner: any LogHandler) {
        self.inner = inner
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.inner[metadataKey: key] }
        set { self.inner[metadataKey: key] = newValue }
    }

    func log(event: LogEvent) {
        var mutatedEvent = event
        if var eventMetadata = event.metadata {
            for (key, value) in eventMetadata {
                var attrs = value.attributes
                attrs[AttrB.self] = .b1
                eventMetadata[key]?.attributes = attrs
            }
            mutatedEvent.metadata = eventMetadata
        }
        self.inner.log(event: mutatedEvent)
    }
}

/// Intermediate handler that strips all attributes before forwarding.
private struct AttributeStrippingHandler: LogHandler {
    var logLevel: Logger.Level {
        get { self.inner.logLevel }
        set { self.inner.logLevel = newValue }
    }

    var metadata: Logger.Metadata {
        get { self.inner.metadata }
        set { self.inner.metadata = newValue }
    }

    var metadataProvider: Logger.MetadataProvider? {
        get { self.inner.metadataProvider }
        set { self.inner.metadataProvider = newValue }
    }

    private var inner: any LogHandler

    init(wrapping inner: any LogHandler) {
        self.inner = inner
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.inner[metadataKey: key] }
        set { self.inner[metadataKey: key] = newValue }
    }

    func log(event: LogEvent) {
        var mutatedEvent = event
        if var eventMetadata = event.metadata {
            for (key, _) in eventMetadata {
                eventMetadata[key]?.attributes = .init()
            }
            mutatedEvent.metadata = eventMetadata
        }
        self.inner.log(event: mutatedEvent)
    }
}
