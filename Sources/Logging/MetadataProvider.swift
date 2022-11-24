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

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#elseif os(Windows)
import CRT
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#else
#error("Unsupported runtime")
#endif

public extension Logger {
    /// A `MetadataProvider` is used to automatically inject runtime-generated metadata
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
    struct MetadataProvider: Sendable {
        /// A default no-op metadata provider, which always returns empty metadata.
        public static var noop: MetadataProvider {
            MetadataProvider { [:] }
        }

        /// Return the ``Logger/MetadataProvider-swift.struct`` that was configured during ``LoggingSystem/bootstrap(_:)-8ffrb``.
        static func bootstrapped(label: String) -> MetadataProvider {
            LoggingSystem.metadataProviderFactory(label)
        }

        /// Provide ``Logger.Metadata`` from current context.
        @usableFromInline
        internal let _provideMetadata: @Sendable() -> Metadata

        #if DEBUG
        let file: String
        let line: UInt
        #endif

        /// Create a new `MetadataProvider`.
        ///
        /// - Parameter provideMetadata: A closure extracting metadata from a given `Baggage`.
        public init(_ provideMetadata: @escaping () -> Metadata, file: String = #fileID, line: UInt = #line) {
            self._provideMetadata = provideMetadata
            #if DEBUG
            self.file = file
            self.line = line
            #endif
        }

        /// Invoke the metadata provider and return the generated contextual ``Logger/Metadata``.
        public func provideMetadata() -> Metadata {
            self._provideMetadata()
        }
    }
}

public extension Logger.MetadataProvider {
    /// A pseudo-`MetadataProvider` that can be used to merge metadata from multiple other `MetadataProvider`s.
    ///
    /// ### Merging conflicting keys
    ///
    /// `MetadataProvider`s are invoked left to right in the order specified in the `providers` argument.
    /// In case multiple providers try to add a value for the same key, the last provider "wins" and its value is being used.
    ///
    /// - Parameter providers: An array of `MetadataProvider`s to delegate to. The array must not be empty.
    /// - Returns: A pseudo-`MetadataProvider` merging metadata from the given `MetadataProvider`s.
    static func multiplex(_ providers: [Logger.MetadataProvider]) -> Logger.MetadataProvider {
        assert(!providers.isEmpty, "providers MUST NOT be empty")
        return Logger.MetadataProvider {
            providers.reduce(into: [:]) { metadata, provider in
                let providedMetadata = provider.provideMetadata()
                guard !providedMetadata.isEmpty else {
                    return
                }
                metadata.merge(providedMetadata, uniquingKeysWith: { _, rhs in rhs })
            }
        }
    }
}
