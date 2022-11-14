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

#if swift(>=5.5) && canImport(_Concurrency)
public typealias _TestBaggage_Sendable = Swift.Sendable
#else
public typealias _TestBaggage_Sendable = Any
#endif

actor A {
    @TaskLocal
    static var name: String?
    
    func test() async {
        await TestBaggage.withValue(.topLevel) {
            await self.asyncFunc()
        }
    }
    
    func asyncFunc() async {} 
}

/// Minimal `Baggage`-like type replicating how `swift-distributed-tracing-baggage` works, so we can showcase how to use it in tests.
public struct TestBaggage: _TestBaggage_Sendable {
    private var _storage = [AnyTestBaggageKey: _TestBaggage_Sendable]()

    init() {}
}

// MARK: - Creating TestBaggage

extension TestBaggage {
    public static var topLevel: TestBaggage {
        TestBaggage()
    }
}

// MARK: - Interacting with TestBaggage

extension TestBaggage {
    public subscript<Key: TestBaggageKey>(_ key: Key.Type) -> Key.Value? {
        get {
            guard let value = self._storage[AnyTestBaggageKey(key)] else { return nil }
            // safe to force-cast as this subscript is the only way to set a value.
            return (value as! Key.Value)
        }
        set {
            self._storage[AnyTestBaggageKey(key)] = newValue
        }
    }
}

extension TestBaggage {
    public var count: Int {
        self._storage.count
    }

    public var isEmpty: Bool {
        self._storage.isEmpty
    }

}

// MARK: - Propagating TestBaggage

#if swift(>=5.5) && canImport(_Concurrency)
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension TestBaggage {
    @TaskLocal public static var current: TestBaggage?

    public static func withValue<T>(_ value: TestBaggage?, operation: () throws -> T) rethrows -> T {
        try TestBaggage.$current.withValue(value, operation: operation)
    }

    public static func withValue<T>(_ value: TestBaggage?, operation: () async throws -> T) async rethrows -> T {
        try await TestBaggage.$current.withValue(value, operation: operation)
    }
}
#endif

public protocol TestBaggageKey: _TestBaggage_Sendable {
    associatedtype Value: _TestBaggage_Sendable
}

extension TestBaggageKey {
    public static var nameOverride: String? { nil }
}

public struct AnyTestBaggageKey: _TestBaggage_Sendable {
    public let keyType: Any.Type

    init<Key: TestBaggageKey>(_ keyType: Key.Type) {
        self.keyType = keyType
    }
}

extension AnyTestBaggageKey: Hashable {
    public static func == (lhs: AnyTestBaggageKey, rhs: AnyTestBaggageKey) -> Bool {
        ObjectIdentifier(lhs.keyType) == ObjectIdentifier(rhs.keyType)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self.keyType))
    }
}
