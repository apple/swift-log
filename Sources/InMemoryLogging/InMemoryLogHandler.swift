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
    /// The canonical metadata store — attributed metadata is the source of truth.
    /// Plain `metadata` is a derived view over this store.
    public var attributedMetadata: Logger.AttributedMetadata = [:]

    /// Get or set plain metadata as a view over attributed metadata.
    ///
    /// - On get: strips attributes and returns raw values.
    /// - On set: stores values with empty attributes.
    public var metadata: Logger.Metadata {
        get {
            self.attributedMetadata.mapValues(\.value)
        }
        set {
            self.attributedMetadata = newValue.mapValues { .init($0, attributes: .init()) }
        }
    }

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

        private var _attributedMetadata: Logger.AttributedMetadata

        /// The plain metadata which was logged (attributes stripped).
        public var metadata: Logger.Metadata {
            get { self._attributedMetadata.mapValues(\.value) }
            set { self._attributedMetadata = newValue.mapValues { .init($0, attributes: .init()) } }
        }

        /// The attributed metadata which was logged.
        public var attributedMetadata: Logger.AttributedMetadata {
            get { self._attributedMetadata }
            set { self._attributedMetadata = newValue }
        }

        public init(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata) {
            self.level = level
            self.message = message
            self._attributedMetadata = metadata.mapValues { .init($0, attributes: .init()) }
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
            self._attributedMetadata = metadata.mapValues { .init($0, attributes: .init()) }
        }

        public init(
            level: Logger.Level,
            message: Logger.Message,
            error: (any Error)?,
            attributedMetadata: Logger.AttributedMetadata
        ) {
            self.level = level
            self.message = message
            self.error = error
            self._attributedMetadata = attributedMetadata
        }

        public static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.level == rhs.level
                && lhs.message == rhs.message
                && lhs._attributedMetadata == rhs._attributedMetadata
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
            attributedMetadata: Logger.AttributedMetadata
        ) {
            self.lock.withLockVoid {
                self._entries.append(
                    Entry(
                        level: level,
                        message: message,
                        error: error,
                        attributedMetadata: attributedMetadata
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
        // Merge metadata in order of precedence:
        // 1. Handler's attributed metadata (lowest precedence)
        // 2. Metadata provider values
        // 3. Event's attributed metadata (highest precedence)
        var merged = Logger.AttributedMetadata()

        // 1. Handler's attributed metadata (lowest precedence)
        for (key, value) in self.attributedMetadata {
            merged[key] = value
        }

        // 2. Metadata provider values
        if let provider = self.metadataProvider {
            for (key, value) in provider.getAttributedMetadata() {
                merged[key] = value
            }
        }

        // 3. Event's attributed metadata (highest precedence)
        if let eventAttributed = event.attributedMetadata {
            for (key, value) in eventAttributed {
                merged[key] = value
            }
        }

        self.logStore.append(
            level: event.level,
            message: event.message,
            error: event.error,
            attributedMetadata: merged
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
            self.attributedMetadata[key]?.value
        }
        set {
            if let newValue {
                self.attributedMetadata[key] = .init(newValue, attributes: .init())
            } else {
                self.attributedMetadata[key] = nil
            }
        }
    }

    public subscript(attributedMetadataKey key: String) -> Logger.AttributedMetadataValue? {
        get {
            self.attributedMetadata[key]
        }
        set {
            self.attributedMetadata[key] = newValue
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
