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

public import Logging

/// A custom log handler which just collects logs into memory.
/// You can then retrieve an array of those log entries.
/// Example use cases include testing and buffering.
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
/// // Use logger to emit some logs
/// someFunction(logger: logger)
///
/// // Retrieve what was logged
/// let logEntries = logger.entries
/// ```
///
public struct InMemoryLogHandler: LogHandler {
    public var metadata: Logger.Metadata = [:]
    public var metadataProvider: Logger.MetadataProvider?
    public var logLevel: Logger.Level = .info
    private let logStore: LogStore

    /// A struct representing a log entry.
    public struct Entry: Sendable, Equatable {
        /// The level we logged at.
        public var level: Logger.Level
        /// The message which was logged.
        public var message: Logger.Message
        /// The error which was logged.
        public var error: (any Error)?
        /// The metadata which was logged.
        public var metadata: Logger.Metadata

        public init(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata) {
            self.level = level
            self.message = message
            self.metadata = metadata
        }

        public init(
            level: Logger.Level,
            message: Logger.Message,
            error: (any Error)?,
            metadata: Logger.Metadata
        ) {
            self.level = level
            self.message = message
            self.error = error
            self.metadata = metadata
        }

        public static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.level == rhs.level
                && lhs.message == rhs.message
                && lhs.metadata == rhs.metadata
                && errorsEqual(lhs.error, rhs.error)
        }

        private static func errorsEqual(_ lhs: (any Error)?, _ rhs: (any Error)?) -> Bool {
            switch (lhs, rhs) {
            case (nil, nil):
                return true
            case let (l?, r?):
                return "\(l)" == "\(r)" && String(reflecting: type(of: l)) == String(reflecting: type(of: r))
            default:
                return false
            }
        }
    }

    private final class LogStore: @unchecked Sendable {
        private var _entries: [Entry] = []
        private let lock = Lock()

        fileprivate func append(
            level: Logger.Level,
            message: Logger.Message,
            error: (any Error)?,
            metadata: Logger.Metadata
        ) {
            self.lock.withLockVoid {
                self._entries.append(
                    Entry(
                        level: level,
                        message: message,
                        error: error,
                        metadata: metadata
                    )
                )
            }
        }

        fileprivate func clear() {
            self.lock.withLockVoid {
                _entries.removeAll()
            }
        }

        var entries: [Entry] {
            self.lock.withLock { self._entries }
        }
    }

    private init(logStore: LogStore) {
        self.logStore = logStore
    }

    /// Create a new ``InMemoryLogHandler``.
    public init() {
        self.init(logStore: .init())
    }

    public func log(event: LogEvent) {
        var merged = self.metadata

        if let provider = self.metadataProvider {
            let provided = provider.get()
            merged.merge(provided, uniquingKeysWith: { _, rhs in rhs })
        }

        if let eventMetadata = event.metadata {
            merged.merge(eventMetadata, uniquingKeysWith: { _, rhs in rhs })
        }

        self.logStore.append(
            level: event.level,
            message: event.message,
            error: event.error,
            metadata: merged
        )
    }

    @available(*, deprecated, renamed: "log(event:)")
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        self.log(
            event: LogEvent(
                level: level,
                message: message,
                metadata: metadata,
                source: source,
                file: file,
                function: function,
                line: line
            )
        )
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
