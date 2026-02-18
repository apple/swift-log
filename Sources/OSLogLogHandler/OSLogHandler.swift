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
import Foundation
import Logging
import os

/// A privacy-aware log handler that uses Apple's unified logging system (os.Logger).
///
/// This handler leverages OSLog's native privacy support to automatically redact
/// private metadata values when viewing logs outside of development environments.
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
/// // Private metadata is automatically redacted in Console.app (non-debug builds)
/// let userId = "12345"
/// logger.info("User logged in", attributedMetadata: [
///     "user.id": "\(userId, privacy: .private)",
///     "action": "\(\"login\", privacy: .public)"
/// ])
/// ```
///
/// ## Privacy Behavior
///
/// - `.private` metadata → OSLog `privacy: .private` (redacted as `<private>` in logs)
/// - `.public` metadata → OSLog `privacy: .public` (always visible)
/// - Plain metadata → Treated as `.public` by default
///
/// ## Implementation Notes
///
/// The handler formats logs with metadata first, followed by a suffix listing private keys:
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
/// In production, the `<private>` marker replaces all private metadata (keys and values).
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
    private let osLogger: os.Logger

    public var metadata: Logging.Logger.Metadata = [:]
    public var metadataProvider: Logging.Logger.MetadataProvider?
    public var logLevel: Logging.Logger.Level = .info
    public var attributedMetadata: Logging.Logger.AttributedMetadata = [:]

    /// Controls whether to append a suffix listing private keys.
    ///
    /// When `true` (default), logs include a suffix like "(keys user.id, token are marked private)"
    /// that clearly indicates which metadata keys contain private values. This helps identify
    /// sensitive data even when values are redacted in production.
    ///
    /// When `false`, private metadata is redacted without any indication of which keys were private.
    ///
    /// ## Example with `showPrivateKeysList = true` (default):
    /// ```
    /// Production: message action=login <private> (keys session.token, user.id are marked private)
    /// Debug:      message action=login session.token=secret user.id=12345 (keys session.token, user.id are marked private)
    /// ```
    ///
    /// ## Example with `showPrivateKeysList = false`:
    /// ```
    /// Production: message action=login <private>
    /// Debug:      message action=login session.token=secret user.id=12345
    /// ```
    public var showPrivateKeysList: Bool = true

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

    /// Log a message with plain metadata.
    public func log(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        metadata: Logging.Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        // Merge metadata
        var mergedMetadata: Logging.Logger.Metadata = self.metadataProvider?.get() ?? [:]
        mergedMetadata = mergedMetadata.merging(self.metadata) { $1 }
        mergedMetadata = mergedMetadata.merging(metadata ?? [:]) { $1 }

        // Log with OSLog - plain metadata is treated as public
        self.logToOSLog(level: level, message: message, metadata: mergedMetadata)
    }

    /// Log a message with attributed metadata (privacy-aware).
    public func log(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        attributedMetadata: Logging.Logger.AttributedMetadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        // Merge attributed metadata
        var merged = Logging.Logger.AttributedMetadata()

        // Add handler's attributed metadata
        for (key, value) in self.attributedMetadata {
            merged[key] = value
        }

        // Add plain metadata as public attributed metadata
        for (key, value) in self.metadata {
            merged[key] = Logging.Logger.AttributedMetadataValue(value, privacy: .public)
        }

        // Add metadata provider values as public
        if let provider = self.metadataProvider {
            for (key, value) in provider.get() {
                merged[key] = Logging.Logger.AttributedMetadataValue(value, privacy: .public)
            }
        }

        // Merge with explicit attributed metadata (takes precedence)
        if let attributedMetadata = attributedMetadata {
            for (key, value) in attributedMetadata {
                merged[key] = value
            }
        }

        // Log with OSLog using privacy annotations
        self.logToOSLogWithPrivacy(level: level, message: message, attributedMetadata: merged)
    }

    public subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get {
            self.metadata[key]
        }
        set {
            self.metadata[key] = newValue
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

    private func logToOSLog(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        metadata: Logging.Logger.Metadata
    ) {
        let osLogType = self.mapLogLevel(level)

        if metadata.isEmpty {
            osLogger.log(level: osLogType, "\(message.description)")
        } else {
            let metadataString = self.formatMetadata(metadata)
            // Plain metadata is treated as public
            osLogger.log(level: osLogType, "\(message.description) \(metadataString, privacy: .public)")
        }
    }

    private func logToOSLogWithPrivacy(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        attributedMetadata: Logging.Logger.AttributedMetadata
    ) {
        let osLogType = self.mapLogLevel(level)

        if attributedMetadata.isEmpty {
            osLogger.log(level: osLogType, "\(message.description)")
            return
        }

        // Separate metadata by privacy level
        let publicMetadata = attributedMetadata.filter { $0.value.attributes.privacy == .public }
        let privateMetadata = attributedMetadata.filter { $0.value.attributes.privacy == .private }

        // Format the suffix showing which keys are private (if enabled)
        let privateKeysSuffix = self.showPrivateKeysList ? self.formatPrivateKeysSuffix(privateMetadata) : ""

        // Format all metadata as key=value
        let publicString = self.formatAttributedMetadataValues(publicMetadata)
        let privateString = self.formatAttributedMetadataValues(privateMetadata)

        // Use OSLog's native privacy annotations
        // Format: "message publicKey=value privateKey=<private> (keys privateKey are marked private)"
        switch (!publicString.isEmpty, !privateString.isEmpty) {
        case (true, true):
            osLogger.log(
                level: osLogType,
                "\(message.description) \(publicString, privacy: .public) \(privateString, privacy: .private)\(privateKeysSuffix, privacy: .public)"
            )
        case (true, false):
            osLogger.log(level: osLogType, "\(message.description) \(publicString, privacy: .public)")
        case (false, true):
            osLogger.log(
                level: osLogType,
                "\(message.description) \(privateString, privacy: .private)\(privateKeysSuffix, privacy: .public)"
            )
        case (false, false):
            osLogger.log(level: osLogType, "\(message.description)")
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

    private func formatMetadata(_ metadata: Logging.Logger.Metadata) -> String {
        metadata
            .map { key, value in
                "\(key)=\(value)"
            }
            .joined(separator: " ")
    }

    private func formatAttributedMetadataValues(_ metadata: Logging.Logger.AttributedMetadata) -> String {
        metadata
            .sorted(by: { $0.key < $1.key })
            .map { key, attributedValue in
                "\(key)=\(attributedValue.value)"
            }
            .joined(separator: " ")
    }

    private func formatPrivateKeysSuffix(_ metadata: Logging.Logger.AttributedMetadata) -> String {
        // Format: " (keys key1, key2 are marked private)" - shows which keys have private values
        // Empty string if no private metadata
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
