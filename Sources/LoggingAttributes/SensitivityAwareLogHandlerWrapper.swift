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

public import Logging

/// A wrapper that adds sensitivity-aware logging capabilities to any `LogHandler`.
///
/// This wrapper intercepts log events, merges handler and provider metadata, applies redaction
/// based on the configured `sensitivityBehavior`, then forwards the processed event to the
/// wrapped handler.
///
/// ## Example Usage
///
/// ```swift
/// let streamHandler = StreamLogHandler.standardOutput(label: "my-app")
/// var handler = SensitivityAwareLogHandlerWrapper(
///     wrapping: streamHandler,
///     sensitivityBehavior: .redact
/// )
///
/// let logger = Logger(label: "my-app") { _ in handler }
///
/// logger.log(level: .info, "User action", attributedMetadata: [
///     "user.id": "\(userId, sensitivity: .sensitive)",
///     "action": "\(action, sensitivity: .public)"
/// ])
/// ```
public struct SensitivityAwareLogHandlerWrapper: LogHandler {
    /// The redaction marker used for redacted values.
    ///
    /// Redacted metadata values are replaced with this string when a handler performs redaction.
    public static let redactionMarker = "<redacted>"

    /// Defines how sensitive metadata should be handled.
    public enum SensitivityBehavior: Sendable {
        /// Log all metadata including values marked as sensitive.
        case log

        /// Redact metadata values marked with `.sensitive`.
        case redact
    }

    /// The underlying log handler that performs the actual logging.
    private var wrappedHandler: any LogHandler

    /// The sensitivity behavior for this handler.
    public var sensitivityBehavior: SensitivityBehavior

    /// The metadata provider.
    ///
    /// Stored on the wrapper, not forwarded to the wrapped handler. The wrapper merges
    /// provider metadata in its own `log(event:)` before forwarding the fully-merged event
    /// to the wrapped handler, avoiding double-merge.
    public var metadataProvider: Logger.MetadataProvider?

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
    ///
    /// This is a view over `attributedMetadata` — setting a value here stores it with empty
    /// attributes, and getting strips attributes from attributed values.
    public var metadata: Logger.Metadata {
        get {
            self._attributedMetadata.mapValues(\.value)
        }
        set {
            self._attributedMetadata = newValue.mapValues { .init($0, attributes: .init()) }
        }
    }

    /// Get or set the entire attributed metadata storage as a dictionary.
    public var attributedMetadata: Logger.AttributedMetadata {
        get { self._attributedMetadata }
        set { self._attributedMetadata = newValue }
    }

    private var _attributedMetadata: Logger.AttributedMetadata = [:]

    /// Creates a sensitivity-aware wrapper around an existing log handler.
    ///
    /// - Parameters:
    ///   - wrappedHandler: The log handler to wrap.
    ///   - sensitivityBehavior: How sensitive metadata should be handled. Defaults to `.redact`.
    public init(wrapping wrappedHandler: any LogHandler, sensitivityBehavior: SensitivityBehavior = .redact) {
        var handler = wrappedHandler
        // Take ownership of the provider to avoid double-merge — the wrapper
        // merges provider metadata itself before forwarding to the wrapped handler.
        self.metadataProvider = handler.metadataProvider
        handler.metadataProvider = nil
        self.wrappedHandler = handler
        self.sensitivityBehavior = sensitivityBehavior
    }

    /// Handle log events, applying redaction for sensitive metadata.
    ///
    /// Merges handler metadata, provider metadata, and event metadata in order of precedence.
    /// Sensitive values are replaced in-place and the modified event is forwarded
    /// to the wrapped handler via `log(event:)`.
    public func log(event: LogEvent) {
        // Merge handler attributed metadata, provider metadata, and event attributed metadata
        var merged = Logger.AttributedMetadata()

        // 1. Handler's attributed metadata (lowest precedence)
        for (key, value) in self._attributedMetadata {
            merged[key] = value
        }

        // 2. Metadata provider values (preserving attributes from attributed providers)
        if let provider = self.metadataProvider {
            for (key, value) in provider.getAttributed() {
                merged[key] = value
            }
        }

        // 3. Event's attributed metadata (highest precedence)
        if let eventAttributed = event.attributedMetadata {
            for (key, value) in eventAttributed {
                merged[key] = value
            }
        }

        guard !merged.isEmpty else {
            self.wrappedHandler.log(event: event)
            return
        }

        // When not redacting, forward merged metadata directly — no second pass needed.
        if self.sensitivityBehavior == .log {
            var mutatedEvent = event
            mutatedEvent.attributedMetadata = merged
            self.wrappedHandler.log(event: mutatedEvent)
            return
        }

        // Redact sensitive values, preserving all other attributes for downstream middleware.
        var processed = Logger.AttributedMetadata()
        for (key, attributedValue) in merged {
            if attributedValue.attributes.sensitivity == .sensitive {
                var redacted = attributedValue
                redacted.value = .string(Self.redactionMarker)
                processed[key] = redacted
            } else {
                processed[key] = attributedValue
            }
        }

        // Forward as attributed metadata via LogEvent
        var mutatedEvent = event
        mutatedEvent.attributedMetadata = processed
        self.wrappedHandler.log(event: mutatedEvent)
    }

    /// Add, change, or remove a logging metadata item.
    ///
    /// This is a view over attributed metadata — values are stored with empty attributes.
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            self._attributedMetadata[metadataKey]?.value
        }
        set {
            if let newValue {
                self._attributedMetadata[metadataKey] = .init(newValue, attributes: .init())
            } else {
                self._attributedMetadata[metadataKey] = nil
            }
        }
    }

    /// Add, change, or remove an attributed logging metadata item.
    public subscript(attributedMetadataKey attributedMetadataKey: String) -> Logger.AttributedMetadataValue? {
        get {
            self._attributedMetadata[attributedMetadataKey]
        }
        set {
            self._attributedMetadata[attributedMetadataKey] = newValue
        }
    }
}
