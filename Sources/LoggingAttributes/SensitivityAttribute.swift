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

public import Logging

extension Logger {
    /// Sensitivity classification for metadata values.
    ///
    /// Tells the handler whether this value contains sensitive data or is safe to emit as-is.
    /// This is a classification hint, not a security guarantee — the handler may or may not
    /// act on it.
    ///
    /// ## Usage
    ///
    /// Use string interpolation with the sensitivity parameter:
    ///
    /// ```swift
    /// logger.info("User action", attributedMetadata: [
    ///     "user.id": "\(userId, sensitivity: .sensitive)",
    ///     "action": "\(action, sensitivity: .public)",
    /// ])
    /// ```
    @frozen
    public enum Sensitivity: Int, Sendable, CaseIterable, Equatable, Hashable, CustomStringConvertible,
        MetadataAttributeKey
    {
        /// This value contains sensitive data that handlers may choose to redact.
        case sensitive = 1

        /// This value is safe to emit as-is.
        case `public` = 2

        /// A textual representation of the sensitivity classification.
        public var description: String {
            switch self {
            case .sensitive: "sensitive"
            case .public: "public"
            }
        }
    }
}

// MARK: - MetadataValueAttributes sensitivity convenience

extension Logger.MetadataValueAttributes {
    /// The sensitivity classification for this metadata value, if set.
    @inlinable
    public var sensitivity: Logger.Sensitivity? {
        get { self[Logger.Sensitivity.self] }
        set { self[Logger.Sensitivity.self] = newValue }
    }

    /// Create metadata value attributes with the specified sensitivity classification.
    @inlinable
    public init(sensitivity: Logger.Sensitivity) {
        self.init()
        self[Logger.Sensitivity.self] = sensitivity
    }
}

// MARK: - AttributedMetadataValue sensitivity convenience

extension Logger.AttributedMetadataValue {
    /// Convenience initializer for creating attributed metadata with a sensitivity classification.
    public init(_ value: Logger.MetadataValue, sensitivity: Logger.Sensitivity) {
        self.init(value, attributes: Logger.MetadataValueAttributes(sensitivity: sensitivity))
    }
}

// MARK: - StringInterpolation sensitivity convenience

extension Logger.AttributedMetadataValue.StringInterpolation {
    /// Interpolation with explicit sensitivity parameter.
    ///
    /// When a single `AttributedMetadataValue` contains multiple interpolated segments with
    /// different sensitivity levels, the **strictest level wins** — if any segment is
    /// `.sensitive`, the entire value becomes `.sensitive`. A `.public` segment cannot
    /// downgrade a previously set `.sensitive` classification.
    ///
    /// ```swift
    /// // The value is .sensitive because any segment is .sensitive:
    /// let mixed: Logger.AttributedMetadataValue =
    ///     "User \(userId, sensitivity: .sensitive) did \(action, sensitivity: .public)"
    /// // mixed.attributes.sensitivity == .sensitive
    /// ```
    @inlinable
    public mutating func appendInterpolation<T>(_ value: T, sensitivity: Logger.Sensitivity)
    where T: CustomStringConvertible & Sendable {
        self.appendInterpolation(
            value,
            attributes: { attrs in
                // The overall sensitivity level is the strictest across interpolated values
                if attrs[Logger.Sensitivity.self] != .sensitive {
                    attrs[Logger.Sensitivity.self] = sensitivity
                }
            }
        )
    }
}
