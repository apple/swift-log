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

// MARK: - MetadataValueAttributes storage

extension Logger {
    /// Attributes that can be associated with metadata values.
    ///
    /// `MetadataValueAttributes` stores one attribute inline without heap allocation. When more than one attribute
    /// is needed, additional attributes spill over to a heap-allocated array.
    /// Use the generic subscript to get/set attributes by their ``Attribute`` type.
    public struct MetadataValueAttributes: Sendable {
        /// A protocol for defining custom metadata attributes.
        ///
        /// Conform to this protocol to define a custom attribute that can be stored in
        /// ``MetadataValueAttributes``. Each conforming type acts as both the key (identified
        /// by its metatype) and the value.
        ///
        /// This protocol is designed for **small, fixed-vocabulary attributes** represented as
        /// enums. Each attribute value is stored as an `Int64` raw value, so attributes occupy minimal
        /// space (one inline slot without heap allocation for the common single-attribute case).
        /// Attributes that need to carry associated data, strings, or richer payloads are outside
        /// the scope of this protocol.
        ///
        /// ## Example
        ///
        /// ```swift
        /// public enum Priority: Int64, Sendable, Logger.MetadataValueAttributes.Attribute {
        ///     case low = 1
        ///     case high = 2
        /// }
        /// ```
        public protocol Attribute: Sendable, RawRepresentable where RawValue == Int64 {}

        /// An entry in the metadata attributes storage.
        @usableFromInline
        internal struct Entry: Sendable, Equatable {
            @usableFromInline
            internal var key: ObjectIdentifier

            @usableFromInline
            internal var value: Int64

            @inlinable
            internal init(key: ObjectIdentifier, value: Int64) {
                self.key = key
                self.value = value
            }
        }

        @usableFromInline
        internal var _inline: Entry?

        @usableFromInline
        internal var _overflow: [Entry]?

        /// Create empty metadata value attributes.
        @inlinable
        public init() {}

        /// Create metadata value attributes using a builder closure.
        ///
        /// ```swift
        /// let attrs = Logger.MetadataValueAttributes {
        ///     $0[Sensitivity.self] = .sensitive
        ///     $0[Priority.self] = .high
        /// }
        /// ```
        @inlinable
        public init(_ build: (inout Self) -> Void) {
            self.init()
            build(&self)
        }

        /// Get or set a custom attribute by its type.
        ///
        /// - Parameter attribute: The metatype of the attribute to access.
        /// - Returns: The attribute value, or `nil` if not set.
        @inlinable
        public subscript<Attr: Attribute>(attribute: Attr.Type) -> Attr? {
            get {
                let id = ObjectIdentifier(Attr.self)
                if let inline = self._inline, inline.key == id { return Attr(rawValue: inline.value) }
                if let overflow = self._overflow {
                    for entry in overflow {
                        if entry.key == id { return Attr(rawValue: entry.value) }
                    }
                }
                return nil
            }
            set {
                let id = ObjectIdentifier(Attr.self)
                if let v = newValue {
                    self._upsert(key: id, value: v.rawValue)
                } else {
                    self._remove(key: id)
                }
            }
        }

        @inlinable
        internal mutating func _upsert(key id: ObjectIdentifier, value: Int64) {
            let entry = Entry(key: id, value: value)
            if let inline = self._inline, inline.key == id {
                self._inline = entry
                return
            }
            if let idx = self._overflow?.firstIndex(where: { $0.key == id }) {
                self._overflow?[idx] = entry
                return
            }
            if self._inline == nil {
                self._inline = entry
            } else {
                if self._overflow == nil {
                    self._overflow = [entry]
                } else {
                    self._overflow?.append(entry)
                }
            }
        }

        @inlinable
        internal mutating func _remove(key id: ObjectIdentifier) {
            if let inline = self._inline, inline.key == id {
                if var overflow = self._overflow, !overflow.isEmpty {
                    self._inline = overflow.removeLast()
                    self._overflow = overflow.isEmpty ? nil : overflow
                } else {
                    self._inline = nil
                }
                return
            }
            if let idx = self._overflow?.firstIndex(where: { $0.key == id }) {
                self._overflow?.remove(at: idx)
                if self._overflow?.isEmpty == true {
                    self._overflow = nil
                }
            }
        }

        @inlinable
        internal mutating func _merge(from other: Self) {
            if let inline = other._inline {
                self._upsert(key: inline.key, value: inline.value)
            }
            if let overflow = other._overflow {
                for entry in overflow {
                    self._upsert(key: entry.key, value: entry.value)
                }
            }
        }

        /// Compare all entries as an unordered set.
        ///
        /// The inline slot and overflow array may hold the same logical entries in different
        /// positions depending on insertion order. This method checks set equality by
        /// verifying that every entry on one side exists on the other. O(n²) but n is
        /// typically 1–2.
        @inlinable
        internal func _isEqual(to other: Self) -> Bool {
            let lhsOverflowCount = self._overflow?.count ?? 0
            let rhsOverflowCount = other._overflow?.count ?? 0
            let lhsCount = (self._inline != nil ? 1 : 0) + lhsOverflowCount
            let rhsCount = (other._inline != nil ? 1 : 0) + rhsOverflowCount
            guard lhsCount == rhsCount else { return false }
            guard lhsCount > 0 else { return true }

            // Check that every lhs entry exists in rhs.
            // With matching counts, this is sufficient for set equality.
            if let inline = self._inline {
                if !other._contains(inline) { return false }
            }
            if let overflow = self._overflow {
                for entry in overflow {
                    if !other._contains(entry) { return false }
                }
            }
            return true
        }

        @inlinable
        internal func _contains(_ entry: Entry) -> Bool {
            if self._inline == entry { return true }
            if let overflow = self._overflow {
                for e in overflow {
                    if e == entry { return true }
                }
            }
            return false
        }
    }
}

extension Logger.MetadataValueAttributes: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._isEqual(to: rhs)
    }
}

extension Logger.MetadataValueAttributes: ExpressibleByArrayLiteral {
    /// Creates metadata value attributes from an array literal of attribute values.
    ///
    /// Each element is any ``Attribute`` conforming value. The key is
    /// inferred from the concrete type of the value.
    ///
    /// ```swift
    /// let attrs: Logger.MetadataValueAttributes = [Sensitivity.sensitive, ValueType.int64]
    /// ```
    /// Each element goes through existential boxing to extract `type(of:)` and `.rawValue`.
    /// This is acceptable for a literal initializer but should not be used in hot paths;
    /// prefer the type-safe subscript (`attrs[SomeAttribute.self] = value`) for performance-sensitive code.
    @inlinable
    public init(arrayLiteral elements: any Logger.MetadataValueAttributes.Attribute...) {
        self.init()
        for element in elements {
            self._upsert(key: ObjectIdentifier(type(of: element)), value: element.rawValue)
        }
    }
}

// MARK: - AttributedStringCarrier

extension Logger {
    /// Internal carrier that wraps a string with metadata attributes.
    ///
    /// Produced by `MetadataValue.StringInterpolation` when any interpolation
    /// segment specifies attributes, or by ``MetadataValue/attributed(_:attributes:)``.
    /// This is the only type that carries attributes; the `.attributes` property on
    /// `MetadataValue` checks for it with a concrete type comparison rather than a
    /// protocol conformance lookup.
    @usableFromInline
    internal final class AttributedStringCarrier: CustomStringConvertible, Sendable {
        @usableFromInline
        internal let string: String

        @usableFromInline
        internal let metadataAttributes: Logger.MetadataValueAttributes

        @usableFromInline
        internal init(string: String, metadataAttributes: Logger.MetadataValueAttributes) {
            self.string = string
            self.metadataAttributes = metadataAttributes
        }

        @inlinable
        internal var description: String { self.string }
    }
}

// MARK: - MetadataValue attributes API

extension Logger.MetadataValue {
    /// The attributes associated with this metadata value, if any.
    ///
    /// **Getting:** When the value is a ``stringConvertible(_:)`` wrapping an
    /// `AttributedStringCarrier`, returns that carrier's attributes.
    /// For all other cases returns empty attributes.
    ///
    /// **Setting:** Replaces the value with `.stringConvertible(AttributedStringCarrier(...))`
    /// carrying the given attributes. For `.string` and `.stringConvertible` cases the string
    /// representation is preserved. For `.dictionary` and `.array` cases the setter is a no-op.
    ///
    /// Only handlers that inspect attributes pay the cost of the getter check.
    @inlinable
    public var attributes: Logger.MetadataValueAttributes {
        get {
            if case .stringConvertible(let box) = self,
                let carrier = box as? Logger.AttributedStringCarrier
            {
                return carrier.metadataAttributes
            }
            return .init()
        }
        set {
            switch self {
            case .string(let s):
                self = .stringConvertible(
                    Logger.AttributedStringCarrier(string: s, metadataAttributes: newValue)
                )
            case .stringConvertible(let box):
                self = .stringConvertible(
                    Logger.AttributedStringCarrier(string: box.description, metadataAttributes: newValue)
                )
            case .dictionary, .array:
                assertionFailure("Cannot set attributes on .dictionary or .array metadata values")
                return
            }
        }
    }

    /// Creates an attributed metadata value from a string-convertible value and attributes.
    ///
    /// This is a convenience factory that behaves like an additional enum case, producing
    /// a `.stringConvertible(AttributedStringCarrier(...))` value without string interpolation:
    ///
    /// ```swift
    /// let value: Logger.MetadataValue = .attributed(userId, attributes: [Sensitivity.sensitive])
    /// ```
    @inlinable
    public static func attributed(
        _ value: some CustomStringConvertible & Sendable,
        attributes: Logger.MetadataValueAttributes
    ) -> Self {
        .stringConvertible(
            Logger.AttributedStringCarrier(
                string: String(describing: value),
                metadataAttributes: attributes
            )
        )
    }
}

// MARK: - Attributed string interpolation

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9687
extension Logger.MetadataValue: ExpressibleByStringInterpolation {
    /// Custom string interpolation that optionally captures metadata attributes.
    ///
    /// When no attributes are specified, produces `.string(...)` — identical to the
    /// default `DefaultStringInterpolation` behavior. When any interpolation segment
    /// specifies attributes (via the `attributes:` parameter), the result is
    /// `.stringConvertible(AttributedStringCarrier(...))` carrying both the string
    /// and the accumulated attributes.
    ///
    /// Attribute packages (like `LoggingAttributes`) can add overloads with
    /// domain-specific parameters (e.g. `sensitivity:`) that call through to
    /// `appendInterpolation(_:attributes:)`.
    public struct StringInterpolation: StringInterpolationProtocol, Sendable {
        @usableFromInline
        internal var output: String = ""

        @usableFromInline
        internal var attributes: Logger.MetadataValueAttributes = .init()

        @usableFromInline
        internal var hasAttributes: Bool = false

        @inlinable
        public init(literalCapacity: Int, interpolationCount: Int) {
            self.output.reserveCapacity(literalCapacity + interpolationCount * 2)
        }

        @inlinable
        public mutating func appendLiteral(_ literal: String) {
            self.output.append(literal)
        }

        /// Interpolation with a custom attributes closure.
        ///
        /// When called, the result will be `.stringConvertible(AttributedStringCarrier(...))`
        /// instead of `.string(...)`.
        ///
        /// ```swift
        /// "\(userId, attributes: { $0[MyAttribute.self] = .flagged })"
        /// ```
        @inlinable
        public mutating func appendInterpolation<T>(
            _ value: T,
            attributes: @Sendable (inout Logger.MetadataValueAttributes) -> Void
        ) where T: CustomStringConvertible & Sendable {
            self.output.append(value.description)
            attributes(&self.attributes)
            self.hasAttributes = true
        }

        /// Interpolation with pre-built attributes.
        ///
        /// ```swift
        /// "\(userId, attributes: [Sensitivity.sensitive])"
        /// ```
        @inlinable
        public mutating func appendInterpolation<T>(
            _ value: T,
            attributes: Logger.MetadataValueAttributes
        ) where T: CustomStringConvertible & Sendable {
            self.output.append(value.description)
            if self.hasAttributes {
                self.attributes._merge(from: attributes)
            } else {
                self.attributes = attributes
            }
            self.hasAttributes = true
        }

        /// Plain interpolation without attributes.
        @inlinable
        public mutating func appendInterpolation<T>(
            _ value: T
        ) where T: CustomStringConvertible & Sendable {
            self.output.append(value.description)
        }

        /// Fallback interpolation for types that are not `CustomStringConvertible`.
        @inlinable
        public mutating func appendInterpolation<T>(
            _ value: T
        ) where T: Sendable {
            self.output.append(String(describing: value))
        }

        /// Unconstrained fallback for non-`Sendable` types.
        @inlinable
        public mutating func appendInterpolation<T>(
            _ value: T
        ) {
            self.output.append(String(describing: value))
        }
    }

    /// Creates a metadata value from string interpolation.
    ///
    /// If any interpolation segment specified attributes, the result is
    /// `.stringConvertible(AttributedStringCarrier(...))`. Otherwise, `.string(...)`.
    @inlinable
    public init(stringInterpolation: StringInterpolation) {
        if stringInterpolation.hasAttributes {
            self = .stringConvertible(
                Logger.AttributedStringCarrier(
                    string: stringInterpolation.output,
                    metadataAttributes: stringInterpolation.attributes
                )
            )
        } else {
            self = .string(stringInterpolation.output)
        }
    }
}
