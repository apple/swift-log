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

/// A wrapper that adds privacy-aware logging capabilities to any `LogHandler`.
///
/// This wrapper intercepts attributed metadata logging calls and applies privacy redaction
/// based on the configured `privacyBehavior`, then forwards the processed metadata to the
/// wrapped handler. Plain metadata logging calls are forwarded directly to the wrapped handler.
///
/// ## Example Usage
///
/// ```swift
/// // Wrap any existing log handler
/// let streamHandler = StreamLogHandler.standardOutput(label: "my-app")
/// var privacyHandler = PrivacyAwareLogHandlerWrapper(
///     wrapping: streamHandler,
///     privacyBehavior: .redact
/// )
///
/// let logger = Logger(label: "my-app") { _ in privacyHandler }
///
/// // Private metadata will be redacted to ***
/// let userId = "12345"
/// let action = "login"
/// logger.log(level: .info, "User action", attributedMetadata: [
///     "user.id": "\(userId, privacy: .private)",
///     "action": "\(action, privacy: .public)"
/// ])
/// ```
public struct PrivacyAwareLogHandlerWrapper: LogHandler {
    /// Defines how private metadata should be handled.
    public enum PrivacyBehavior: Sendable {
        /// Log all metadata including private values.
        case log

        /// Redact private metadata values (replaces with "***").
        case redact
    }

    /// The underlying log handler that performs the actual logging.
    private var wrappedHandler: any LogHandler

    /// The privacy behavior for this handler.
    public var privacyBehavior: PrivacyBehavior

    /// The metadata provider.
    public var metadataProvider: Logger.MetadataProvider? {
        get {
            self.wrappedHandler.metadataProvider
        }
        set {
            self.wrappedHandler.metadataProvider = newValue
        }
    }

    /// Get or set the log level configured for this handler.
    public var logLevel: Logger.Level {
        get {
            self.wrappedHandler.logLevel
        }
        set {
            self.wrappedHandler.logLevel = newValue
        }
    }

    /// Get or set the entire metadata storage as a dictionary.
    public var metadata: Logger.Metadata {
        get {
            self.wrappedHandler.metadata
        }
        set {
            self.wrappedHandler.metadata = newValue
        }
    }

    /// Get or set the entire attributed metadata storage as a dictionary.
    public var attributedMetadata: Logger.AttributedMetadata = [:]

    /// Creates a privacy-aware wrapper around an existing log handler.
    ///
    /// - Parameters:
    ///   - wrappedHandler: The log handler to wrap.
    ///   - privacyBehavior: How private metadata should be handled. Defaults to `.redact`.
    public init(wrapping wrappedHandler: any LogHandler, privacyBehavior: PrivacyBehavior = .redact) {
        self.wrappedHandler = wrappedHandler
        self.privacyBehavior = privacyBehavior
    }

    /// Forward plain metadata logging to the wrapped handler.
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        self.wrappedHandler.log(
            level: level,
            message: message,
            metadata: metadata,
            source: source,
            file: file,
            function: function,
            line: line
        )
    }

    /// Handle attributed metadata logging with privacy redaction.
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        attributedMetadata: Logger.AttributedMetadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        // Merge handler metadata, provider metadata, and explicit attributed metadata
        var merged = Logger.AttributedMetadata()

        // Add handler's attributed metadata
        for (key, value) in self.attributedMetadata {
            merged[key] = value
        }

        // Merge with explicit attributed metadata (takes precedence)
        if let attributedMetadata = attributedMetadata {
            for (key, value) in attributedMetadata {
                merged[key] = value
            }
        }

        // Convert attributed metadata to plain metadata based on privacy behavior
        let processedMetadata: Logger.Metadata = merged.reduce(into: [:]) { result, element in
            let (key, attributedValue) = element
            switch (attributedValue.attributes.privacy, self.privacyBehavior) {
            case (.public, _):
                // Public metadata is always logged
                result[key] = attributedValue.value
            case (.private, .log):
                // Log private values when configured to log all
                result[key] = attributedValue.value
            case (.private, .redact):
                // Redact private values as ***
                result[key] = .string("***")
            }
        }

        // Forward to wrapped handler with processed attributed metadata
        self.wrappedHandler.log(
            level: level,
            message: message,
            metadata: processedMetadata.isEmpty ? nil : processedMetadata,
            source: source,
            file: file,
            function: function,
            line: line
        )
    }

    /// Add, change, or remove a logging metadata item.
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            self.wrappedHandler[metadataKey: metadataKey]
        }
        set {
            self.wrappedHandler[metadataKey: metadataKey] = newValue
        }
    }

    /// Add, change, or remove an attributed logging metadata item.
    public subscript(attributedMetadataKey attributedMetadataKey: String) -> Logger.AttributedMetadataValue? {
        get {
            self.attributedMetadata[attributedMetadataKey]
        }
        set {
            self.attributedMetadata[attributedMetadataKey] = newValue
        }
    }
}
