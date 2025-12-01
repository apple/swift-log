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

import Logging
import Synchronization

/// A custom log handler which doesn't actually emit logs, but just collects them into memory.
/// You can then retrieve a list of what was logged and run assertions on it.
/// This handler is intended to be used in tests.
///
/// # Usage
/// ```swift
/// let logHandler = InMemoryLogHandler()
/// let logger = Logger(
///     label: "MyApp",
///     factory: { _ in
///       logHandler
///     }
/// )
/// // Use logger to emit some logs, then:
/// let logEntries = logger.entries
/// #expect(logEntries.contains(...))
/// ```
///
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct InMemoryLogHandler: LogHandler {
    public var metadata: Logger.Metadata = [:]
    public var metadataProvider: Logger.MetadataProvider?
    public var logLevel: Logger.Level = .info
    private let logStore: LogStore

    /// A single item which was logged.
    public struct Entry: Sendable, Equatable {
        /// The level we logged at.
        public var level: Logger.Level
        /// The message which was logged.
        public var message: Logger.Message
        /// The metadata which was logged.
        public var metadata: Logger.Metadata

        public init(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata) {
            self.level = level
            self.message = message
            self.metadata = metadata
        }
    }

    final class LogStore: Sendable {
        private let logs: Mutex<[Entry]> = .init([])

        fileprivate func append(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata) {
            self.logs.withLock {
                $0.append(
                    Entry(
                        level: level,
                        message: message,
                        metadata: metadata
                    )
                )
            }
        }

        fileprivate func clear() {
            self.logs.withLock {
                $0.removeAll()
            }
        }

        var entries: [Entry] {
            self.logs.withLock { $0 }
        }
    }

    private init(logStore: LogStore) {
        self.logStore = logStore
    }

    /// Create a new ``InMemoryLogHandler``.
    public init() {
        self.init(logStore: .init())
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        // Start with the metadata provider..
        var mergedMetadata: Logger.Metadata = self.metadataProvider?.get() ?? [:]
        // ..merge in self.metadata, overwriting existing keys
        mergedMetadata = mergedMetadata.merging(self.metadata) { $1 }
        // ..merge in metadata from this log call, overwriting existing keys
        mergedMetadata = mergedMetadata.merging(metadata ?? [:]) { $1 }

        self.logStore.append(level: level, message: message, metadata: mergedMetadata)
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get {
            self.metadata[key]
        }
        set {
            self.metadata[key] = newValue
        }
    }

    /// All logs that have been collected.
    public var entries: [Entry] {
        self.logStore.entries
    }

    /// Clear all entries.
    public func clear() {
        self.logStore.clear()
    }
}
