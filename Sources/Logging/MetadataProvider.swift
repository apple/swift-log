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

#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import CRT
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#else
#error("Unsupported runtime")
#endif

@preconcurrency protocol _SwiftLogSendable: Sendable {}

extension Logger {
    /// A MetadataProvider automatically injects runtime-generated metadata
    /// to all logs emitted by a logger.
    ///
    /// ### Example
    /// A metadata provider may be used to automatically inject metadata such as
    /// trace IDs:
    ///
    /// ```swift
    /// import Tracing // https://github.com/apple/swift-distributed-tracing
    ///
    /// let metadataProvider = MetadataProvider {
    ///     guard let traceID = Baggage.current?.traceID else { return nil }
    ///     return ["traceID": "\(traceID)"]
    /// }
    /// let logger = Logger(label: "example", metadataProvider: metadataProvider)
    /// var baggage = Baggage.topLevel
    /// baggage.traceID = 42
    /// Baggage.withValue(baggage) {
    ///     logger.info("hello") // automatically includes ["traceID": "42"] metadata
    /// }
    /// ```
    ///
    /// We recommend referring to [swift-distributed-tracing](https://github.com/apple/swift-distributed-tracing)
    /// for metadata providers which make use of its tracing and metadata propagation infrastructure. It is however
    /// possible to make use of metadata providers independently of tracing and instruments provided by that library,
    /// if necessary.
    public struct MetadataProvider: _SwiftLogSendable {
        /// Provide ``Logger.Metadata`` from the current context.
        @usableFromInline
        internal let _provideMetadata: @Sendable () -> Metadata

        /// Creates a new metadata provider.
        ///
        /// - Parameter provideMetadata: A closure that extracts metadata from the current execution context.
        public init(_ provideMetadata: @escaping @Sendable () -> Metadata) {
            self._provideMetadata = provideMetadata
        }

        /// Invokes the metadata provider and returns the generated contextual metadata.
        public func get() -> Metadata {
            self._provideMetadata()
        }
    }
}

extension Logger.MetadataProvider {
    /// A pseudo metadata provider that merges metadata from multiple other metadata providers.
    ///
    /// ### Merging conflicting keys
    ///
    /// `MetadataProvider`s are invoked left to right in the order specified in the `providers` argument.
    /// In case multiple providers try to add a value for the same key, the last provider "wins" and its value is being used.
    ///
    /// - Parameter providers: An array of `MetadataProvider`s to delegate to. The array must not be empty.
    /// - Returns: A pseudo-`MetadataProvider` merging metadata from the given `MetadataProvider`s.
    public static func multiplex(_ providers: [Logger.MetadataProvider]) -> Logger.MetadataProvider? {
        assert(!providers.isEmpty, "providers MUST NOT be empty")
        return Logger.MetadataProvider {
            providers.reduce(into: [:]) { metadata, provider in
                let providedMetadata = provider.get()
                guard !providedMetadata.isEmpty else {
                    return
                }
                metadata.merge(providedMetadata, uniquingKeysWith: { _, rhs in rhs })
            }
        }
    }
}
