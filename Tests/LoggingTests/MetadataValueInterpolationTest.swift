//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Logging
import Testing

// MARK: - Helper types covering each overload

/// `TextOutputStreamable & CustomStringConvertible` — exercises the most-specific overload.
private struct StreamingAndDescribing: TextOutputStreamable, CustomStringConvertible {
    let value: Int
    var description: String { "SD(\(self.value))" }
    func write<Target: TextOutputStream>(to target: inout Target) {
        target.write(self.description)
    }
}

/// `TextOutputStreamable` only — exercises the TOS-only overload. (Rare in practice.)
private struct StreamingOnly: TextOutputStreamable {
    let value: Int
    func write<Target: TextOutputStream>(to target: inout Target) {
        target.write("SO(\(self.value))")
    }
}

/// `CustomStringConvertible` only — exercises the CSC-only overload.
private struct DescribingOnly: CustomStringConvertible {
    let value: Int
    var description: String { "DO(\(self.value))" }
}

/// Neither TOS nor CSC — exercises the unconstrained fallback.
private struct PlainStruct {
    let value: Int
}

/// Non-`Sendable` reference type — exercises the unconstrained overload and verifies
/// that the constraint relaxation in `appendInterpolation` accepts non-`Sendable` arguments.
private final class NonSendableBox {
    var value: Int
    init(_ value: Int) { self.value = value }
}

@Suite("MetadataValue String Interpolation")
struct MetadataValueInterpolationTests {

    // MARK: - Plain interpolation by overload overload

    @Test("String interpolates via TOS & CSC overload")
    func plainString() {
        let value: Logger.MetadataValue = "hello \("world")"
        #expect(value.description == "hello world")
    }

    @Test("Int interpolates via TOS & CSC overload")
    func plainInt() {
        let value: Logger.MetadataValue = "n=\(42)"
        #expect(value.description == "n=42")
    }

    @Test("Double interpolates via TOS & CSC overload")
    func plainDouble() {
        let value: Logger.MetadataValue = "x=\(1.5)"
        #expect(value.description == "x=1.5")
    }

    @Test("Substring interpolates via TOS & CSC overload")
    func plainSubstring() {
        let s = "hello world"
        let value: Logger.MetadataValue = "\(s.dropFirst(6))"
        #expect(value.description == "world")
    }

    @Test("Custom TOS & CSC type uses the most-specific overload")
    func plainStreamingAndDescribing() {
        let value: Logger.MetadataValue = "\(StreamingAndDescribing(value: 7))"
        #expect(value.description == "SD(7)")
    }

    @Test("TOS-only type interpolates via the TOS overload")
    func plainStreamingOnly() {
        let value: Logger.MetadataValue = "\(StreamingOnly(value: 9))"
        #expect(value.description == "SO(9)")
    }

    @Test("CSC-only type interpolates via .description")
    func plainDescribingOnly() {
        let value: Logger.MetadataValue = "\(DescribingOnly(value: 3))"
        #expect(value.description == "DO(3)")
    }

    @Test("Array (CSC, not TOS) interpolates via .description")
    func plainArray() {
        let value: Logger.MetadataValue = "\([1, 2, 3])"
        #expect(value.description == "[1, 2, 3]")
    }

    @Test("Foundation.Data (CSC) interpolates via .description")
    func plainData() {
        let data = Data([0x41, 0x42])
        let value: Logger.MetadataValue = "\(data)"
        #expect(value.description == data.description)
    }

    @Test("Plain struct (no CSC, no TOS) falls through to String(describing:)")
    func plainPlainStruct() {
        let value: Logger.MetadataValue = "\(PlainStruct(value: 5))"
        #expect(value.description == String(describing: PlainStruct(value: 5)))
    }

    @Test("Non-Sendable class falls through to String(describing:) and compiles")
    func plainNonSendable() {
        let box = NonSendableBox(11)
        let value: Logger.MetadataValue = "\(box)"
        #expect(value.description == String(describing: box))
    }

    // MARK: - Optional interpolation with a default

    @Test("nil optional uses the default string")
    func defaultNil() {
        let value: Int? = nil
        let result: Logger.MetadataValue = "\(value, default: "none")"
        #expect(result.description == "none")
    }

    @Test("non-nil optional interpolates the wrapped value")
    func defaultSome() {
        let value: Int? = 42
        let result: Logger.MetadataValue = "\(value, default: "none")"
        #expect(result.description == "42")
    }

    @Test("nil optional of a TOS-only type uses the default")
    func defaultNilStreamingOnly() {
        let value: StreamingOnly? = nil
        let result: Logger.MetadataValue = "\(value, default: "missing")"
        #expect(result.description == "missing")
    }

    @Test("non-nil optional of a CSC-only type interpolates via .description")
    func defaultSomeDescribingOnly() {
        let value: DescribingOnly? = DescribingOnly(value: 3)
        let result: Logger.MetadataValue = "\(value, default: "missing")"
        #expect(result.description == "DO(3)")
    }

    @Test("nil optional of a non-CSC, non-TOS type uses the default")
    func defaultNilUnconstrained() {
        let value: PlainStruct? = nil
        let result: Logger.MetadataValue = "\(value, default: "absent")"
        #expect(result.description == "absent")
    }

    @Test("default accepts a Substring (some StringProtocol)")
    func defaultSubstring() {
        let value: Int? = nil
        let fallback = "n/a value".dropFirst(4)
        let result: Logger.MetadataValue = "\(value, default: fallback)"
        #expect(result.description == "value")
    }

    @Test("default segment mixed with plain segments")
    func defaultMultiSegment() {
        let name: String? = nil
        let result: Logger.MetadataValue = "user=\(name, default: "anon") id=\(42)"
        #expect(result.description == "user=anon id=42")
    }

    @Test("default interpolation yields .string case")
    func defaultYieldsStringCase() {
        let value: Int? = nil
        let result: Logger.MetadataValue = "\(value, default: "none")"
        if case .string(let s) = result {
            #expect(s == "none")
        } else {
            Issue.record("Expected .string case, got \(result)")
        }
    }

    // MARK: - Overloaded return types

    @Test("Overloaded function returning String/Data/[UInt8] disambiguates to String")
    func overloadedReturnTypeAmbiguity() {
        func someFunc() -> String { "from-string" }
        func someFunc() -> Data { Data([0x00]) }
        func someFunc() -> [UInt8] { [0xFF] }

        // Without the TOS & CSC overload this would fail with "ambiguous use of 'someFunc()'".
        // String wins because it's TOS & CSC; Data and [UInt8] are CSC-only.
        let value: Logger.MetadataValue = "\(someFunc())"
        #expect(value.description == "from-string")
    }

    // MARK: - Closure-attribute interpolation

    @Test("Closure attributes attach to a TOS & CSC value")
    func closureAttrsTOSAndCSC() {
        let value: Logger.MetadataValue = "\(42, attributes: { $0[AttrA.self] = .a1 })"
        #expect(value.description == "42")
        #expect(value.attributes[AttrA.self] == .a1)
    }

    @Test("Closure attributes attach to a CSC-only value")
    func closureAttrsCSC() {
        let value: Logger.MetadataValue = "\(DescribingOnly(value: 1), attributes: { $0[AttrA.self] = .a1 })"
        #expect(value.description == "DO(1)")
        #expect(value.attributes[AttrA.self] == .a1)
    }

    @Test("Closure attributes attach to a TOS-only value")
    func closureAttrsTOS() {
        let value: Logger.MetadataValue = "\(StreamingOnly(value: 2), attributes: { $0[AttrA.self] = .a1 })"
        #expect(value.description == "SO(2)")
        #expect(value.attributes[AttrA.self] == .a1)
    }

    @Test("Closure attributes attach to a non-CSC, non-TOS value")
    func closureAttrsUnconstrained() {
        let s = PlainStruct(value: 4)
        let value: Logger.MetadataValue = "\(s, attributes: { $0[AttrA.self] = .a1 })"
        #expect(value.description == String(describing: s))
        #expect(value.attributes[AttrA.self] == .a1)
    }

    @Test("Closure attributes accept a non-Sendable value")
    func closureAttrsNonSendable() {
        let box = NonSendableBox(13)
        let value: Logger.MetadataValue = "\(box, attributes: { $0[AttrA.self] = .a1 })"
        #expect(value.description == String(describing: box))
        #expect(value.attributes[AttrA.self] == .a1)
    }

    // MARK: - Pre-built attribute interpolation

    @Test("Pre-built attributes attach to a TOS & CSC value")
    func valueAttrsTOSAndCSC() {
        let value: Logger.MetadataValue = "\(42, attributes: [AttrA.a1, AttrB.b2])"
        #expect(value.description == "42")
        #expect(value.attributes[AttrA.self] == .a1)
        #expect(value.attributes[AttrB.self] == .b2)
    }

    @Test("Pre-built attributes attach to a CSC-only value")
    func valueAttrsCSC() {
        let value: Logger.MetadataValue = "\(DescribingOnly(value: 8), attributes: [AttrA.a1])"
        #expect(value.description == "DO(8)")
        #expect(value.attributes[AttrA.self] == .a1)
    }

    @Test("Pre-built attributes attach to a non-CSC value")
    func valueAttrsUnconstrained() {
        let s = PlainStruct(value: 6)
        let value: Logger.MetadataValue = "\(s, attributes: [AttrA.a1])"
        #expect(value.description == String(describing: s))
        #expect(value.attributes[AttrA.self] == .a1)
    }

    @Test("Pre-built attributes accept a non-Sendable value")
    func valueAttrsNonSendable() {
        let box = NonSendableBox(17)
        let value: Logger.MetadataValue = "\(box, attributes: [AttrA.a1])"
        #expect(value.description == String(describing: box))
        #expect(value.attributes[AttrA.self] == .a1)
    }

    @Test("Empty attributes still produce an attributed result")
    func valueAttrsEmpty() {
        let value: Logger.MetadataValue = "\(42, attributes: Logger.MetadataValueAttributes())"
        #expect(value.description == "42")
        // No attribute keys are set, but the carrier exists.
        #expect(value.attributes[AttrA.self] == nil)
    }

    // MARK: - Multi-segment interpolation

    @Test("Plain + plain segments concatenate without attributes")
    func multiPlain() {
        let value: Logger.MetadataValue = "user=\("alice") id=\(42)"
        #expect(value.description == "user=alice id=42")
        #expect(value.attributes[AttrA.self] == nil)
    }

    @Test("Plain + attributed segments produce attributed result")
    func multiPlainAndAttributed() {
        let value: Logger.MetadataValue = "user=\("alice") action=\("login", attributes: [AttrA.a1])"
        #expect(value.description == "user=alice action=login")
        #expect(value.attributes[AttrA.self] == .a1)
    }

    @Test("Two attributed segments merge their attributes")
    func multiAttributedMerge() {
        let value: Logger.MetadataValue = "\("a", attributes: [AttrA.a1])-\("b", attributes: [AttrB.b2])"
        #expect(value.description == "a-b")
        #expect(value.attributes[AttrA.self] == .a1)
        #expect(value.attributes[AttrB.self] == .b2)
    }

    @Test("Closure-attributes and value-attributes segments merge")
    func multiAttributedMixed() {
        let value: Logger.MetadataValue =
            "\("x", attributes: { $0[AttrA.self] = .a1 })-\("y", attributes: [AttrB.b2])"
        #expect(value.description == "x-y")
        #expect(value.attributes[AttrA.self] == .a1)
        #expect(value.attributes[AttrB.self] == .b2)
    }

    @Test("Conflicting attribute keys: later segment wins")
    func multiAttributedConflict() {
        let value: Logger.MetadataValue =
            "\("a", attributes: [AttrA.a1])-\("b", attributes: [AttrA.a2])"
        #expect(value.description == "a-b")
        #expect(value.attributes[AttrA.self] == .a2)
    }

    // MARK: - Result-case discrimination

    @Test("Plain interpolation yields .string case")
    func plainYieldsStringCase() {
        let value: Logger.MetadataValue = "\(42)"
        if case .string(let s) = value {
            #expect(s == "42")
        } else {
            Issue.record("Expected .string case, got \(value)")
        }
    }

    @Test("Attributed interpolation yields .stringConvertible case")
    func attributedYieldsStringConvertibleCase() {
        let value: Logger.MetadataValue = "\(42, attributes: [AttrA.a1])"
        if case .stringConvertible = value {
            // ok
        } else {
            Issue.record("Expected .stringConvertible case, got \(value)")
        }
    }
}
