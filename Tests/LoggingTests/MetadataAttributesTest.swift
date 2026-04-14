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

enum AttrA: Int, Logger.MetadataAttributeKey {
    case a1 = 1
    case a2 = 2
}

enum AttrB: Int, Logger.MetadataAttributeKey {
    case b1 = 1
    case b2 = 2
}

enum AttrC: Int, Logger.MetadataAttributeKey {
    case c1 = 1
    case c2 = 2
}

enum AttrD: Int, Logger.MetadataAttributeKey {
    case d1 = 1
    case d2 = 2
}

enum AttrE: Int, Logger.MetadataAttributeKey {
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
}
