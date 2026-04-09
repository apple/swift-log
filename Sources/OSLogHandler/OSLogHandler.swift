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

#if canImport(os)
public import Logging
import LoggingAttributes
import os

/// A redaction-aware log handler that uses Apple's unified logging system (os.Logger).
///
/// This handler leverages OSLog's native privacy support to automatically redact
/// metadata values marked with `.sensitive` when viewing logs outside of
/// development environments.
///
/// ## Features
///
/// - **Native Privacy Support**: Uses OSLog's `privacy: .private` and `privacy: .public` annotations
/// - **System Integration**: Logs appear in Console.app and can be viewed with `log` command
/// - **Performance**: Zero-cost when logging is disabled at the system level
/// - **Subsystem Organization**: Groups logs by subsystem and category for better filtering
///
/// ## Usage
///
/// ```swift
/// // Create an OSLog handler with subsystem and category
/// let handler = OSLogHandler(subsystem: "com.example.myapp", category: "network")
/// let logger = Logger(label: "network") { _ in handler }
///
/// // Metadata marked with .sensitive is automatically redacted in Console.app (non-debug builds)
/// let userId = "12345"
/// logger.info("User logged in", attributedMetadata: [
///     "user.id": "\(userId, sensitivity: .sensitive)",
///     "action": "\(\"login\", sensitivity: .public)"
/// ])
/// ```
///
/// ## Redaction Behavior
///
/// - `.sensitive` metadata -> OSLog `privacy: .private` (redacted as `<private>` in logs)
/// - `.public` metadata -> OSLog `privacy: .public` (always visible)
/// - Plain metadata -> Treated as `.public` by default
///
/// ## Implementation Notes
///
/// The handler formats logs with metadata first, followed by a suffix listing redacted keys:
///
/// **Production logs (Console.app, non-debug builds):**
/// ```
/// message action=login <private> (keys session.token, user.id are marked private)
/// ```
///
/// **Debug builds:**
/// ```
/// message action=login session.token=secret user.id=12345 (keys session.token, user.id are marked private)
/// ```
///
/// In production, the `<private>` marker replaces all redacted metadata (keys and values).
/// The suffix clearly indicates which keys were redacted, making it easy to identify
/// sensitive data that OSLog has protected.
///
/// ## System Requirements
///
/// Available on:
/// - macOS 11.0+
/// - iOS 14.0+
/// - tvOS 14.0+
/// - watchOS 7.0+
///
@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
public struct OSLogHandler: LogHandler {
    private var osLogger: os.Logger

    /// The canonical metadata store — attributed metadata is the source of truth.
    /// Plain `metadata` is a derived view over this store.
    public var attributedMetadata: Logging.Logger.AttributedMetadata = [:]

    /// Get or set plain metadata as a view over attributed metadata.
    ///
    /// - On get: strips attributes and returns raw values.
    /// - On set: stores values with empty attributes (treated as `.public` by default).
    public var metadata: Logging.Logger.Metadata {
        get {
            self.attributedMetadata.mapValues(\.value)
        }
        set {
            self.attributedMetadata = newValue.mapValues { .init($0, attributes: .init()) }
        }
    }

    public var metadataProvider: Logging.Logger.MetadataProvider?
    public var logLevel: Logging.Logger.Level = .info

    /// Controls whether to append a suffix listing redacted keys.
    ///
    /// When `true` (default), logs include a suffix like "(keys user.id, token are marked private)"
    /// that clearly indicates which metadata keys contain redacted values. This helps identify
    /// sensitive data even when values are redacted in production.
    ///
    /// When `false`, redacted metadata is redacted without any indication of which keys were redacted.
    ///
    /// ## Example with `showRedactedKeysList = true` (default):
    /// ```
    /// Production: message action=login <private> (keys session.token, user.id are marked private)
    /// Debug:      message action=login session.token=secret user.id=12345 (keys session.token, user.id are marked private)
    /// ```
    ///
    /// ## Example with `showRedactedKeysList = false`:
    /// ```
    /// Production: message action=login <private>
    /// Debug:      message action=login session.token=secret user.id=12345
    /// ```
    public var showRedactedKeysList: Bool = true

    /// Creates an OSLog handler with the specified subsystem and category.
    ///
    /// - Parameters:
    ///   - subsystem: An identifier string, in reverse DNS notation, that represents the subsystem
    ///                that's performing logging. For example, `com.example.myapp`.
    ///   - category: A category within the specified subsystem. The system uses the category to
    ///               filter related log messages. For example, `network` or `database`.
    public init(subsystem: String, category: String) {
        self.osLogger = os.Logger(subsystem: subsystem, category: category)
    }

    /// Log a message, handling both plain and attributed metadata via `LogEvent`.
    public func log(event: LogEvent) {
        // Merge attributed metadata from handler, provider, and event
        var merged = Logging.Logger.AttributedMetadata()

        // Add handler's attributed metadata (includes both plain and attributed, single store)
        for (key, value) in self.attributedMetadata {
            merged[key] = value
        }

        // Add metadata provider values (preserving attributes from attributed providers)
        if let provider = self.metadataProvider {
            for (key, value) in provider.getAttributed() {
                merged[key] = value
            }
        }

        // Merge with event's attributed metadata (takes precedence)
        if let eventAttributed = event.attributedMetadata {
            for (key, value) in eventAttributed {
                merged[key] = value
            }
        }

        if merged.isEmpty {
            self.osLogger.log(level: self.mapLogLevel(event.level), "\(event.message.description)")
        } else if merged.contains(where: { $0.value.attributes.sensitivity == .sensitive }) {
            // Has redacted content — use privacy-aware logging
            self.logToOSLogWithRedaction(level: event.level, message: event.message, attributedMetadata: merged)
        } else {
            // No redacted content — log as plain public metadata
            let metadataString = merged.sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value.value)" }
                .joined(separator: " ")
            self.osLogger.log(
                level: self.mapLogLevel(event.level),
                "\(event.message.description) \(metadataString, privacy: .public)"
            )
        }
    }

    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
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

    public subscript(attributedMetadataKey key: String) -> Logging.Logger.AttributedMetadataValue? {
        get {
            self.attributedMetadata[key]
        }
        set {
            self.attributedMetadata[key] = newValue
        }
    }

    // MARK: - Private Helpers

    private func logToOSLogWithRedaction(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        attributedMetadata: Logging.Logger.AttributedMetadata
    ) {
        let osLogType = self.mapLogLevel(level)

        // Separate metadata by sensitivity
        let publicMetadata = attributedMetadata.filter { $0.value.attributes.sensitivity != .sensitive }
        let redactedMetadata = attributedMetadata.filter { $0.value.attributes.sensitivity == .sensitive }

        // Format the suffix showing which keys are redacted (if enabled)
        let redactedKeysSuffix = self.showRedactedKeysList ? self.formatRedactedKeysSuffix(redactedMetadata) : ""

        // Format all metadata as key=value
        let publicString = self.formatAttributedMetadataValues(publicMetadata)
        let redactedString = self.formatAttributedMetadataValues(redactedMetadata)

        // Use OSLog's native privacy annotations
        // Format: "message publicKey=value redactedKey=<private> (keys redactedKey are marked private)"
        switch (!publicString.isEmpty, !redactedString.isEmpty) {
        case (true, true):
            self.osLogger.log(
                level: osLogType,
                "\(message.description) \(publicString, privacy: .public) \(redactedString, privacy: .private)\(redactedKeysSuffix, privacy: .public)"
            )
        case (true, false):
            self.osLogger.log(level: osLogType, "\(message.description) \(publicString, privacy: .public)")
        case (false, true):
            self.osLogger.log(
                level: osLogType,
                "\(message.description) \(redactedString, privacy: .private)\(redactedKeysSuffix, privacy: .public)"
            )
        case (false, false):
            self.osLogger.log(level: osLogType, "\(message.description)")
        }
    }

    private func mapLogLevel(_ level: Logging.Logger.Level) -> OSLogType {
        switch level {
        case .trace:
            return .debug
        case .debug:
            return .debug
        case .info:
            return .info
        case .notice:
            // .notice doesn't have a direct OSLog equivalent, using .default
            return .default
        case .warning:
            // .warning maps to .error in OSLog (there's no warning level)
            return .error
        case .error:
            return .error
        case .critical:
            return .fault
        }
    }

    private func formatAttributedMetadataValues(_ metadata: Logging.Logger.AttributedMetadata) -> String {
        metadata
            .sorted(by: { $0.key < $1.key })
            .map { key, attributedValue in
                "\(key)=\(attributedValue.value)"
            }
            .joined(separator: " ")
    }

    private func formatRedactedKeysSuffix(_ metadata: Logging.Logger.AttributedMetadata) -> String {
        // Format: " (keys key1, key2 are marked private)" - shows which keys have redacted values
        // Empty string if no redacted metadata
        if metadata.isEmpty {
            return ""
        }
        let keys = metadata.keys.sorted().joined(separator: ", ")
        let keyWord = metadata.count == 1 ? "key" : "keys"
        let isWord = metadata.count == 1 ? "is" : "are"
        return " (\(keyWord) \(keys) \(isWord) marked private)"
    }
}

#endif
