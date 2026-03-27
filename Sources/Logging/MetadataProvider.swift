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
    /// ### Attributed Metadata Providers
    ///
    /// Metadata providers can also return attributed metadata with privacy levels:
    ///
    /// ```swift
    /// let provider = Logger.MetadataProvider {
    ///     [
    ///         "trace-id": "\(Baggage.current?.traceID, privacy: .public)",
    ///         "user-id": "\(RequestContext.current.userId, privacy: .private)"
    ///     ]
    /// }
    /// ```
    ///
    /// When an attributed provider's ``get()`` method is called (for backward compatibility
    /// with handlers that don't support attributed metadata), private values are redacted
    /// to `"<private>"` to maintain privacy guarantees.
    ///
    /// We recommend referring to [swift-distributed-tracing](https://github.com/apple/swift-distributed-tracing)
    /// for metadata providers which make use of its tracing and metadata propagation infrastructure. It is however
    /// possible to make use of metadata providers independently of tracing and instruments provided by that library,
    /// if necessary.
    public struct MetadataProvider: _SwiftLogSendable {
        @usableFromInline
        internal enum Storage: Sendable {
            case plain(@Sendable () -> Metadata)
            case attributed(@Sendable () -> AttributedMetadata)
        }

        @usableFromInline
        internal let storage: Storage

        /// Internal initializer for creating a metadata provider from storage.
        @usableFromInline
        internal init(storage: Storage) {
            self.storage = storage
        }

        /// Creates a new metadata provider that returns plain metadata.
        ///
        /// - Parameter provideMetadata: A closure that extracts metadata from the current execution context.
        public init(_ provideMetadata: @escaping @Sendable () -> Metadata) {
            self.storage = .plain(provideMetadata)
        }

        /// Creates a new metadata provider that returns attributed metadata.
        ///
        /// Attributed metadata providers allow you to specify privacy levels and other
        /// attributes for each metadata value. When accessed through the plain ``get()``
        /// method (for backward compatibility), private values are redacted to `"<private>"`.
        ///
        /// ### Example
        ///
        /// ```swift
        /// let provider = Logger.MetadataProvider {
        ///     [
        ///         "request-id": "\(RequestContext.current.id, privacy: .public)",
        ///         "user-id": "\(RequestContext.current.userId, privacy: .private)"
        ///     ]
        /// }
        /// ```
        ///
        /// - Parameter provideAttributed: A closure that extracts attributed metadata from the current execution context.
        /// - Returns: A metadata provider that returns attributed metadata.
        @_disfavoredOverload
        public init(_ provideMetadata: @escaping @Sendable () -> AttributedMetadata) {
            self.storage = .attributed(provideMetadata)
        }

        /// Invokes the metadata provider and returns the generated contextual metadata.
        ///
        /// If this is an attributed provider, private metadata values are redacted to
        /// `"<private>"` to maintain privacy guarantees when accessed through the plain
        /// metadata API.
        ///
        /// - Returns: Plain metadata dictionary with private values redacted if applicable.
        public func get() -> Metadata {
            switch self.storage {
            case .plain(let provide):
                return provide()
            case .attributed(let provide):
                // Redact private metadata values to "<private>"
                var result: Metadata = [:]
                for (key, attributed) in provide() {
                    if attributed.attributes.privacy == .public {
                        result[key] = attributed.value
                    } else {
                        result[key] = .string("<private>")
                    }
                }
                return result
            }
        }

        /// Returns attributed metadata if this is an attributed provider.
        ///
        /// This method returns the full attributed metadata including all privacy levels.
        /// Handlers that support attributed metadata should call this method first,
        /// falling back to ``get()`` if it returns nil.
        ///
        /// - Returns: Attributed metadata with all values and attributes if this is an
        ///            attributed provider, or nil if this is a plain provider.
        public func getAttributed() -> AttributedMetadata? {
            switch self.storage {
            case .plain:
                return nil
            case .attributed(let provide):
                return provide()
            }
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
    /// ### Attributed metadata support
    ///
    /// The multiplex provider checks at invocation time if any provider returns attributed metadata.
    /// If so, all metadata is combined as attributed (plain metadata is converted to `.public`).
    /// Otherwise, plain metadata is returned for backward compatibility.
    ///
    /// - Parameter providers: An array of `MetadataProvider`s to delegate to. The array must not be empty.
    /// - Returns: A pseudo-`MetadataProvider` merging metadata from the given `MetadataProvider`s.
    public static func multiplex(_ providers: [Logger.MetadataProvider]) -> Logger.MetadataProvider? {
        assert(!providers.isEmpty, "providers MUST NOT be empty")

        // Create a provider that checks at invocation time whether any provider is attributed
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
