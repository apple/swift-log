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

/// A Logger emits log messages using methods that correspond to a log level.
///
/// `Logger` is a value type with respect to the ``Logger/Level`` and the ``Metadata`` (as well as the immutable `label`
/// and the selected ``LogHandler``).
/// Therefore, you can pass an instance of `Logger` between libraries to preserve metadata across libraries.
///
/// The most basic usage of a `Logger` is:
///
/// ```swift
/// logger.info("Hello World!")
/// ```
public struct Logger {
    /// Storage class to hold the label and log handler
    // The storage implements CoW to become Sendable
    @usableFromInline
    internal final class Storage: @unchecked Sendable {
        @usableFromInline
        var label: String

        @usableFromInline
        var handler: any LogHandler

        @inlinable
        init(label: String, handler: any LogHandler) {
            self.label = label
            self.handler = handler
        }

        @inlinable
        func copy() -> Storage {
            Storage(label: self.label, handler: self.handler)
        }
    }

    @usableFromInline
    internal var _storage: Storage
    public var label: String {
        self._storage.label
    }

    /// The log handler.
    ///
    /// This computed property provides access to the `LogHandler`.
    @inlinable
    public var handler: any LogHandler {
        get {
            self._storage.handler
        }
        set {
            if !isKnownUniquelyReferenced(&self._storage) {
                self._storage = self._storage.copy()
            }
            self._storage.handler = newValue
        }
    }

    /// The metadata provider this logger was created with.
    @inlinable
    public var metadataProvider: Logger.MetadataProvider? {
        self.handler.metadataProvider
    }

    @usableFromInline
    internal init(label: String, _ handler: any LogHandler) {
        self._storage = Storage(label: label, handler: handler)
    }
}

extension Logger {
    /// Log a message using the log level and source that you provide.
    ///
    /// If the `logLevel` passed to this method is more severe than the `Logger`'s ``logLevel``, the library
    /// logs the message, otherwise nothing will happen.
    ///
    /// NOTE: This method adds a constant overhead over calling level-specific methods.
    ///
    /// - parameters:
    ///    - level: The severity level of the `message`.
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func log(
        level: Logger.Level,
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if MaxLogLevelDebug || MaxLogLevelInfo || MaxLogLevelNotice || MaxLogLevelWarning || MaxLogLevelError || MaxLogLevelCritical || MaxLogLevelNone
        // A constant overhead is added for dynamic log level calls if one of the traits is enabled.
        // This allows picking the necessary implementation with compiled out body in runtime.
        switch level {
        case .trace:
            self.trace(
                message(),
                error: error(),
                metadata: metadata(),
                source: source(),
                file: file,
                function: function,
                line: line
            )
        case .debug:
            self.debug(
                message(),
                error: error(),
                metadata: metadata(),
                source: source(),
                file: file,
                function: function,
                line: line
            )
        case .info:
            self.info(
                message(),
                error: error(),
                metadata: metadata(),
                source: source(),
                file: file,
                function: function,
                line: line
            )
        case .notice:
            self.notice(
                message(),
                error: error(),
                metadata: metadata(),
                source: source(),
                file: file,
                function: function,
                line: line
            )
        case .warning:
            self.warning(
                message(),
                error: error(),
                metadata: metadata(),
                source: source(),
                file: file,
                function: function,
                line: line
            )
        case .error:
            self.error(
                message(),
                error: error(),
                metadata: metadata(),
                source: source(),
                file: file,
                function: function,
                line: line
            )
        case .critical:
            self.critical(
                message(),
                error: error(),
                metadata: metadata(),
                source: source(),
                file: file,
                function: function,
                line: line
            )
        }
        #else
        // If no logs are excluded in the compile time, we can avoid checking the log level that extra time and go log it.
        self._log(
            level: level,
            message(),
            error: error(),
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Log a message using the log level and source that you provide.
    ///
    /// If the `logLevel` passed to this method is more severe than the `Logger`'s ``logLevel``, the library
    /// logs the message, otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - level: The severity level of the `message`.
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    package func _log(
        level: Logger.Level,
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        if self.logLevel <= level {
            self.handler.log(
                event: LogEvent(
                    level: level,
                    message: message(),
                    error: error(),
                    metadata: metadata(),
                    source: source(),
                    file: file,
                    function: function,
                    line: line
                )
            )
        }
    }

    /// Log a message using the log level and attributed metadata that you provide.
    ///
    /// This is a package-internal method that contains the runtime level check for attributed metadata.
    /// Per-level convenience methods with compile-time elimination call through to this method.
    ///
    /// - parameters:
    ///    - level: The severity level of the `message`.
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - attributedMetadata: One-off attributed metadata to attach to this log message.
    ///    - source: The source this log message originates from.
    ///    - file: The file this log message originates from.
    ///    - function: The function this log message originates from.
    ///    - line: The line this log message originates from.
    @inlinable
    package func _log(
        level: Logger.Level,
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        attributedMetadata: @autoclosure () -> Logger.AttributedMetadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        if self.logLevel <= level {
            self.handler.log(
                event: LogEvent(
                    level: level,
                    message: message(),
                    error: error(),
                    attributedMetadata: attributedMetadata(),
                    source: source(),
                    file: file,
                    function: function,
                    line: line
                )
            )
        }
    }

    /// Log a message using the log level you provide.
    ///
    /// If the `logLevel` passed to this method is more severe than the `Logger`'s ``logLevel``, the library
    /// logs the message, otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - level: The log level to log the `message`.
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func log(
        level: Logger.Level,
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.log(
            level: level,
            message(),
            error: nil,
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
    }

    /// Log a message using the log level you provide.
    ///
    /// If the `logLevel` passed to this method is more severe than the `Logger`'s ``logLevel``, the library
    /// logs the message, otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - level: The log level to log the `message`.
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func log(
        level: Logger.Level,
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.log(
            level: level,
            message(),
            error: nil,
            metadata: metadata(),
            source: nil,
            file: file,
            function: function,
            line: line
        )
    }

    /// Log a message using the log level and attributed metadata that you provide.
    ///
    /// If the `logLevel` passed to this method is more severe than the `Logger`'s ``logLevel``, the library
    /// logs the message, otherwise nothing will happen.
    ///
    /// NOTE: This method adds a constant overhead over calling level-specific methods.
    ///
    /// - parameters:
    ///    - level: The log level to log the `message`.
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - attributedMetadata: One-off attributed metadata to attach to this log message.
    ///    - source: The source this log message originates from.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func log(
        level: Logger.Level,
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        attributedMetadata: @autoclosure () -> Logger.AttributedMetadata?,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if MaxLogLevelDebug || MaxLogLevelInfo || MaxLogLevelNotice || MaxLogLevelWarning || MaxLogLevelError || MaxLogLevelCritical || MaxLogLevelNone
        // A constant overhead is added for dynamic log level calls if one of the traits is enabled.
        // This allows picking the necessary implementation with compiled out body in runtime.
        switch level {
        case .trace:
            self.trace(
                message(),
                error: error(),
                attributedMetadata: attributedMetadata(),
                source: source(),
                file: file,
                function: function,
                line: line
            )
        case .debug:
            self.debug(
                message(),
                error: error(),
                attributedMetadata: attributedMetadata(),
                source: source(),
                file: file,
                function: function,
                line: line
            )
        case .info:
            self.info(
                message(),
                error: error(),
                attributedMetadata: attributedMetadata(),
                source: source(),
                file: file,
                function: function,
                line: line
            )
        case .notice:
            self.notice(
                message(),
                error: error(),
                attributedMetadata: attributedMetadata(),
                source: source(),
                file: file,
                function: function,
                line: line
            )
        case .warning:
            self.warning(
                message(),
                error: error(),
                attributedMetadata: attributedMetadata(),
                source: source(),
                file: file,
                function: function,
                line: line
            )
        case .error:
            self.error(
                message(),
                error: error(),
                attributedMetadata: attributedMetadata(),
                source: source(),
                file: file,
                function: function,
                line: line
            )
        case .critical:
            self.critical(
                message(),
                error: error(),
                attributedMetadata: attributedMetadata(),
                source: source(),
                file: file,
                function: function,
                line: line
            )
        }
        #else
        // If no logs are excluded in the compile time, we can avoid checking the log level that extra time and go log it.
        self._log(
            level: level,
            message(),
            error: error(),
            attributedMetadata: attributedMetadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Add, change, or remove a logging metadata item.
    ///
    /// > Note: Changing the logging metadata only affects the instance of the `Logger` where you change it.
    @inlinable
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            self.handler[metadataKey: metadataKey]
        }
        set {
            self.handler[metadataKey: metadataKey] = newValue
        }
    }

    /// Add, change, or remove an attributed logging metadata item.
    ///
    /// > Note: Changing the attributed logging metadata only affects the instance of the `Logger` where you change it.
    @inlinable
    public subscript(attributedMetadataKey key: String) -> Logger.AttributedMetadataValue? {
        get {
            self.handler[attributedMetadataKey: key]
        }
        set {
            self.handler[attributedMetadataKey: key] = newValue
        }
    }

    /// Get or set the entire attributed metadata storage as a dictionary.
    ///
    /// > Note: Changing the attributed metadata only affects the instance of the `Logger` where you change it.
    @inlinable
    public var attributedMetadata: Logger.AttributedMetadata {
        get {
            self.handler.attributedMetadata
        }
        set {
            self.handler.attributedMetadata = newValue
        }
    }

    /// Get or set the log level configured for this `Logger`.
    ///
    /// > Note: Changing the log level threshold for a logger only affects the instance of the `Logger` where you change it.
    /// > It is acceptable for logging backends to have some form of global log level override
    /// > that affects multiple or even all loggers. This means a change in `logLevel` to one `Logger` might in
    /// > certain cases have no effect.
    @inlinable
    public var logLevel: Logger.Level {
        get {
            self.handler.logLevel
        }
        set {
            self.handler.logLevel = newValue
        }
    }
}

extension Logger {
    /// Log a message at the 'trace' log level with the source that you provide.
    ///
    /// If ``Level/trace`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func trace(
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if !MaxLogLevelDebug && !MaxLogLevelInfo && !MaxLogLevelNotice && !MaxLogLevelWarning && !MaxLogLevelError && !MaxLogLevelCritical && !MaxLogLevelNone
        self._log(
            level: .trace,
            message(),
            error: error(),
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Log a message at the 'trace' log level with the source that you provide.
    ///
    /// If ``Level/trace`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func trace(
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.trace(
            message(),
            error: nil,
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
    }

    /// Log a message at the 'trace' log level.
    ///
    /// If ``Level/trace`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func trace(
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.trace(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    /// Log a message at the 'debug' log level with the source that you provide.
    ///
    /// If ``Level/debug`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func debug(
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if !MaxLogLevelInfo && !MaxLogLevelNotice && !MaxLogLevelWarning && !MaxLogLevelError && !MaxLogLevelCritical && !MaxLogLevelNone
        self._log(
            level: .debug,
            message(),
            error: error(),
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Log a message at the 'debug' log level with the source that you provide.
    ///
    /// If ``Level/debug`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func debug(
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.debug(
            message(),
            error: nil,
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
    }

    /// Log a message at the 'debug' log level.
    ///
    /// If ``Level/debug`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func debug(
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.debug(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    /// Log a message at the 'info' log level with the source that you provide.
    ///
    /// If ``Level/info`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func info(
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if !MaxLogLevelNotice && !MaxLogLevelWarning && !MaxLogLevelError && !MaxLogLevelCritical && !MaxLogLevelNone
        self._log(
            level: .info,
            message(),
            error: error(),
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Log a message at the 'info' log level with the source that you provide.
    ///
    /// If ``Level/info`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func info(
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.info(
            message(),
            error: nil,
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
    }

    /// Log a message at the 'info' log level.
    ///
    /// If ``Level/info`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func info(
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.info(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    /// Log a message at the 'notice' log level with the source that you provide.
    ///
    /// If ``Level/notice`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func notice(
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if !MaxLogLevelWarning && !MaxLogLevelError && !MaxLogLevelCritical && !MaxLogLevelNone
        self._log(
            level: .notice,
            message(),
            error: error(),
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Log a message at the 'notice' log level with the source that you provide.
    ///
    /// If ``Level/notice`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func notice(
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.notice(
            message(),
            error: nil,
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
    }

    /// Log a message at the 'notice' log level.
    ///
    /// If ``Level/notice`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func notice(
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.notice(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    /// Log a message at the 'warning' log level with the source that you provide.
    ///
    /// If ``Level/warning`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func warning(
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if !MaxLogLevelError && !MaxLogLevelCritical && !MaxLogLevelNone
        self._log(
            level: .warning,
            message(),
            error: error(),
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Log a message at the 'warning' log level with the source that you provide.
    ///
    /// If ``Level/warning`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func warning(
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.warning(
            message(),
            error: nil,
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
    }

    /// Log a message at the 'warning' log level.
    ///
    /// If ``Level/warning`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func warning(
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.warning(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    /// Log a message at the 'error' log level with the source that you provide.
    ///
    /// If ``Level/error`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func error(
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if !MaxLogLevelCritical && !MaxLogLevelNone
        self._log(
            level: .error,
            message(),
            error: error(),
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Log a message at the 'error' log level with the source that you provide.
    ///
    /// If ``Level/error`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func error(
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.error(
            message(),
            error: nil,
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
    }

    /// Log a message at the 'error' log level.
    ///
    /// If ``Level/error`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func error(
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.error(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    /// Log a message at the 'critical' log level with the source that you provide.
    ///
    /// If ``Level/critical`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func critical(
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if !MaxLogLevelNone
        self._log(
            level: .critical,
            message(),
            error: error(),
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Log a message at the 'critical' log level with the source that you provide.
    ///
    /// If ``Level/critical`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func critical(
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.critical(
            message(),
            error: nil,
            metadata: metadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
    }

    /// Log a message at the 'critical' log level.
    ///
    /// If ``Level/critical`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func critical(
        _ message: @autoclosure () -> Logger.Message,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.critical(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    // MARK: - Attributed Metadata Convenience Methods
    /// Log a message at the 'trace' log level with attributed metadata and the source that you provide.
    ///
    /// If ``Level/trace`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - attributedMetadata: One-off attributed metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func trace(
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        attributedMetadata: @autoclosure () -> Logger.AttributedMetadata?,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if !MaxLogLevelDebug && !MaxLogLevelInfo && !MaxLogLevelNotice && !MaxLogLevelWarning && !MaxLogLevelError && !MaxLogLevelCritical && !MaxLogLevelNone
        self._log(
            level: .trace,
            message(),
            error: error(),
            attributedMetadata: attributedMetadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Log a message at the 'debug' log level with attributed metadata and the source that you provide.
    ///
    /// If ``Level/debug`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - attributedMetadata: One-off attributed metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func debug(
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        attributedMetadata: @autoclosure () -> Logger.AttributedMetadata?,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if !MaxLogLevelInfo && !MaxLogLevelNotice && !MaxLogLevelWarning && !MaxLogLevelError && !MaxLogLevelCritical && !MaxLogLevelNone
        self._log(
            level: .debug,
            message(),
            error: error(),
            attributedMetadata: attributedMetadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Log a message at the 'info' log level with attributed metadata and the source that you provide.
    ///
    /// If ``Level/info`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - attributedMetadata: One-off attributed metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func info(
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        attributedMetadata: @autoclosure () -> Logger.AttributedMetadata?,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if !MaxLogLevelNotice && !MaxLogLevelWarning && !MaxLogLevelError && !MaxLogLevelCritical && !MaxLogLevelNone
        self._log(
            level: .info,
            message(),
            error: error(),
            attributedMetadata: attributedMetadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Log a message at the 'notice' log level with attributed metadata and the source that you provide.
    ///
    /// If ``Level/notice`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - attributedMetadata: One-off attributed metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func notice(
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        attributedMetadata: @autoclosure () -> Logger.AttributedMetadata?,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if !MaxLogLevelWarning && !MaxLogLevelError && !MaxLogLevelCritical && !MaxLogLevelNone
        self._log(
            level: .notice,
            message(),
            error: error(),
            attributedMetadata: attributedMetadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Log a message at the 'warning' log level with attributed metadata and the source that you provide.
    ///
    /// If ``Level/warning`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - attributedMetadata: One-off attributed metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func warning(
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        attributedMetadata: @autoclosure () -> Logger.AttributedMetadata?,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if !MaxLogLevelError && !MaxLogLevelCritical && !MaxLogLevelNone
        self._log(
            level: .warning,
            message(),
            error: error(),
            attributedMetadata: attributedMetadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Log a message at the 'error' log level with attributed metadata and the source that you provide.
    ///
    /// If ``Level/error`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - attributedMetadata: One-off attributed metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func error(
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        attributedMetadata: @autoclosure () -> Logger.AttributedMetadata?,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if !MaxLogLevelCritical && !MaxLogLevelNone
        self._log(
            level: .error,
            message(),
            error: error(),
            attributedMetadata: attributedMetadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

    /// Log a message at the 'critical' log level with attributed metadata and the source that you provide.
    ///
    /// If ``Level/critical`` is at least as severe as this logger's ``logLevel`` the system logs the message;
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - error: An `Error` related to the event.
    ///    - attributedMetadata: One-off attributed metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    @inlinable
    public func critical(
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        attributedMetadata: @autoclosure () -> Logger.AttributedMetadata?,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        #if !MaxLogLevelNone
        self._log(
            level: .critical,
            message(),
            error: error(),
            attributedMetadata: attributedMetadata(),
            source: source(),
            file: file,
            function: function,
            line: line
        )
        #endif
    }

}

extension Logger {
    /// The type of the metadata storage.
    ///
    /// `Metadata` is a typealias for `[String: Logger.MetadataValue]` the type of the metadata storage.
    public typealias Metadata = [String: MetadataValue]

    /// A logging metadata value.
    ///
    /// `Logger.MetadataValue` is a string, array, or a dictionary literal convertible.
    ///
    /// `MetadataValue` provides convenient conformances to `ExpressibleByStringInterpolation`,
    /// `ExpressibleByStringLiteral`, `ExpressibleByArrayLiteral`, and `ExpressibleByDictionaryLiteral` which means
    /// that when constructing `MetadataValue`s you should default to using Swift's usual literals.
    ///
    ///
    ///  Prefer using string interpolation for convenience, for example:
    ///  ```swift
    ///  logger.info(
    ///      "user logged in",
    ///      metadata: ["user-id": "\(user.id)"]
    ///  )
    ///  ```
    ///  over:
    ///  ```swift
    ///  logger.info(
    ///      "user logged in",
    ///      metadata: ["user-id": .string(user.id.description)]
    ///  )
    ///  ```
    ///
    ///  Rather than explicitly asserting that the metadata is an array or dictionary, use the string literal to interpolate into the result:
    ///  ```swift
    ///  logger.info(
    ///      "user selected colors",
    ///      metadata: ["colors": ["\(user.topColor)", "\(user.secondColor)"]])
    ///  ```
    ///  over:
    ///  ```swift
    ///  logger.info(
    ///      "user selected colors",
    ///      metadata: [
    ///          "colors": .array([.string("\(user.topColor)"), .string("\(user.secondColor)")
    ///      ]
    ///  )
    ///  ```
    ///
    ///  and an example that illustrates presenting a dictionary:
    ///
    ///  ```swift
    ///  logger.info(
    ///      "nested info",
    ///      metadata: [
    ///        "nested": [
    ///          "fave-numbers": ["\(1)", "\(2)", "\(3)"],
    ///          "foo": "bar"
    ///        ]
    ///      ]
    ///  )
    ///  ```
    ///  over
    ///  ```swift
    ///  logger.info(
    ///      "nested info",
    ///      metadata: [
    ///        "nested": .dictionary([
    ///          "fave-numbers": ["\(1)", "\(2)", "\(3)"],
    ///          "foo": "bar"
    ///        ])
    ///  ])
    ///  ```
    ///
    public enum MetadataValue {
        /// A string metadata value.
        ///
        /// Because `MetadataValue` implements `ExpressibleByStringInterpolation`, and `ExpressibleByStringLiteral`,
        /// you don't need to type `.string(someType.description)` instead the string interpolation `"\(someType)"`.
        case string(String)

        /// A metadata value that conforms to custom string convertible.
        case stringConvertible(any CustomStringConvertible & Sendable)

        /// A metadata value which is a dictionary keyed with strings and storing metadata values.
        ///
        /// The type signature of the dictionary is `[String: Logger.MetadataValue]`.
        ///
        /// Because `MetadataValue` implements `ExpressibleByDictionaryLiteral`, you don't need to type
        /// `.dictionary(["foo": .string("bar \(buz)")])`, instead use the more natural `["foo": "bar \(buz)"]`.
        case dictionary(Metadata)

        /// An array of metadata values.
        ///
        /// Because `MetadataValue` implements `ExpressibleByArrayLiteral`, you don't need to type
        /// `.array([.string("foo"), .string("bar \(buz)")])`, instead use the more natural `["foo", "bar \(buz)"]`.
        case array([Metadata.Value])
    }

    /// A protocol for defining custom metadata attribute keys.
    ///
    /// Conform to this protocol to define a custom attribute that can be stored in
    /// ``MetadataValueAttributes``. Each conforming type acts as both the key (identified
    /// by its metatype) and the value.
    ///
    /// This protocol is designed for **small, fixed-vocabulary attributes** represented as
    /// enums. Each attribute value is stored as an `Int64` raw value, so attributes occupy minimal
    /// space (one inline slot without heap allocation for the common single-attribute case).
    /// Attributes that need to carry associated data, strings, or richer payloads are outside
    /// the scope of this protocol.
    ///
    /// ## Example
    ///
    /// ```swift
    /// public enum Priority: Int64, Sendable, MetadataAttributeKey {
    ///     case low = 1
    ///     case high = 2
    /// }
    /// ```
    public protocol MetadataAttributeKey: Sendable, RawRepresentable where RawValue == Int64 {}

    /// An entry in the metadata attributes storage.
    @usableFromInline
    internal struct MetadataAttributeEntry: Sendable, Equatable {
        @usableFromInline
        internal var key: ObjectIdentifier

        @usableFromInline
        internal var value: Int64

        @inlinable
        internal init(key: ObjectIdentifier, value: Int64) {
            self.key = key
            self.value = value
        }
    }

    /// Attributes that can be associated with metadata values.
    ///
    /// `MetadataValueAttributes` stores one attribute inline without heap allocation. When more than one attribute
    /// is needed, additional attributes spill over to a heap-allocated array.
    /// Use the generic subscript to get/set attributes by their ``MetadataAttributeKey`` type.
    public struct MetadataValueAttributes: Sendable {
        @usableFromInline
        internal var _inline: MetadataAttributeEntry?

        @usableFromInline
        internal var _overflow: [MetadataAttributeEntry]?

        /// Create empty metadata value attributes.
        @inlinable
        public init() {}

        /// Get or set a custom attribute by its key type.
        ///
        /// - Parameter key: The metatype of the attribute key to access.
        /// - Returns: The attribute value, or `nil` if not set.
        @inlinable
        public subscript<Key: MetadataAttributeKey>(key: Key.Type) -> Key? {
            get {
                let id = ObjectIdentifier(Key.self)
                if let inline = self._inline, inline.key == id { return Key(rawValue: inline.value) }
                if let overflow = self._overflow {
                    for entry in overflow {
                        if entry.key == id { return Key(rawValue: entry.value) }
                    }
                }
                return nil
            }
            set {
                let id = ObjectIdentifier(Key.self)
                // Try to update inline slot
                if let inline = self._inline, inline.key == id {
                    if let v = newValue {
                        self._inline = MetadataAttributeEntry(key: id, value: v.rawValue)
                    } else {
                        // Remove inline, promote from overflow if available
                        if var overflow = self._overflow, !overflow.isEmpty {
                            self._inline = overflow.removeLast()
                            self._overflow = overflow.isEmpty ? nil : overflow
                        } else {
                            self._inline = nil
                        }
                    }
                    return
                }
                // Try to update existing overflow entry
                if let idx = self._overflow?.firstIndex(where: { $0.key == id }) {
                    if let v = newValue {
                        self._overflow?[idx] = MetadataAttributeEntry(key: id, value: v.rawValue)
                    } else {
                        self._overflow?.remove(at: idx)
                        if self._overflow?.isEmpty == true {
                            self._overflow = nil
                        }
                    }
                    return
                }
                // Insert new attribute
                guard let v = newValue else { return }
                let entry = MetadataAttributeEntry(key: id, value: v.rawValue)
                if self._inline == nil {
                    self._inline = entry
                } else {
                    if self._overflow == nil {
                        self._overflow = [entry]
                    } else {
                        self._overflow?.append(entry)
                    }
                }
            }
        }

        /// Compare all entries as an unordered set.
        ///
        /// The inline slot and overflow array may hold the same logical entries in different
        /// positions depending on insertion order. This method checks set equality by
        /// verifying that every entry on one side exists on the other. O(n²) but n is
        /// typically 1–2.
        @inlinable
        internal func _isEqual(to other: Self) -> Bool {
            let lhsOverflowCount = self._overflow?.count ?? 0
            let rhsOverflowCount = other._overflow?.count ?? 0
            let lhsCount = (self._inline != nil ? 1 : 0) + lhsOverflowCount
            let rhsCount = (other._inline != nil ? 1 : 0) + rhsOverflowCount
            guard lhsCount == rhsCount else { return false }
            guard lhsCount > 0 else { return true }

            // Check that every lhs entry exists in rhs.
            // With matching counts, this is sufficient for set equality.
            if let inline = self._inline {
                if !other._contains(inline) { return false }
            }
            if let overflow = self._overflow {
                for entry in overflow {
                    if !other._contains(entry) { return false }
                }
            }
            return true
        }

        @inlinable
        internal func _contains(_ entry: MetadataAttributeEntry) -> Bool {
            if self._inline == entry { return true }
            if let overflow = self._overflow {
                for e in overflow {
                    if e == entry { return true }
                }
            }
            return false
        }
    }
}

extension Logger.MetadataValueAttributes: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._isEqual(to: rhs)
    }
}

extension Logger {

    /// A metadata value with associated attributes.
    ///
    /// `AttributedMetadataValue` wraps a standard `MetadataValue` with custom attributes,
    /// allowing you to associate application-defined or handler-defined attributes
    /// with metadata values.
    ///
    /// ## Creating Attributed Metadata
    ///
    /// Use the attributes closure in string interpolation:
    ///
    /// ```swift
    /// logger.info("User action", attributedMetadata: [
    ///     "user.id": "\(userId, attributes: { $0[MyAttribute.self] = .flagged })",
    ///     "action": "\(action)"
    /// ])
    /// ```
    ///
    /// Or create directly:
    ///
    /// ```swift
    /// var attrs = Logger.MetadataValueAttributes()
    /// attrs[MyAttribute.self] = .flagged
    /// let attributed = Logger.AttributedMetadataValue(.string("12345"), attributes: attrs)
    /// ```
    public struct AttributedMetadataValue: Sendable, Equatable, CustomStringConvertible {
        /// The underlying metadata value without attributes.
        public var value: MetadataValue

        /// The attributes associated with this metadata value.
        public var attributes: MetadataValueAttributes

        /// A textual representation of this attributed metadata value.
        public var description: String {
            self.value.description
        }

        /// Create an attributed metadata value with the specified attributes.
        ///
        /// - Parameters:
        ///   - value: The metadata value to wrap.
        ///   - attributes: The attributes for this value.
        public init(_ value: MetadataValue, attributes: MetadataValueAttributes) {
            self.value = value
            self.attributes = attributes
        }
    }

    /// Metadata dictionary with attributes.
    ///
    /// A dictionary mapping string keys to ``AttributedMetadataValue`` instances, used with
    /// the `attributedMetadata` parameter of logging methods.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let userId = "12345"
    /// let requestId = "req-789"
    /// let metadata: Logger.AttributedMetadata = [
    ///     "user.id": "\(userId, attributes: { $0[MyAttribute.self] = .flagged })",
    ///     "request.id": "\(requestId)",
    ///     "action": "purchase"  // String literal defaults to no attributes
    /// ]
    /// logger.info("User action", attributedMetadata: metadata)
    /// ```
    public typealias AttributedMetadata = [String: AttributedMetadataValue]

    /// The log level.
    ///
    /// Log levels are ordered by their severity, with `.trace` being the least severe and
    /// `.critical` being the most severe.
    public enum Level: String, Codable, CaseIterable {
        /// Appropriate for messages that contain information normally of use only when
        /// tracing the execution of a program.
        case trace

        /// Appropriate for messages that contain information normally of use only when debugging a program.
        case debug

        /// Appropriate for informational messages.
        case info

        /// Appropriate for conditions that are not error conditions, but that may require special handling.
        case notice

        /// Appropriate for messages that are not error conditions, but more severe than notice.
        case warning

        /// Appropriate for error conditions.
        case error

        /// Appropriate for critical error conditions that usually require immediate attention.
        ///
        /// When a `critical` message is logged, the logging backend (`LogHandler`) is free to perform
        /// more heavy-weight operations to capture system state (such as capturing stack traces) to facilitate
        /// debugging.
        case critical
    }

    /// Construct a logger with the label you provide to identify the creator of the logger.
    ///
    /// The `label` should identify the creator of the `Logger`.
    /// This can be an application, a sub-system, or a datatype.
    ///
    /// - parameters:
    ///     - label: An identifier for the creator of a `Logger`.
    public init(label: String) {
        self.init(label: label, LoggingSystem.factory(label, LoggingSystem.metadataProvider))
    }

    /// Creates a logger using the label that identifies the creator of the logger or a non-standard log handler.
    ///
    /// The `label` should identify the creator of the `Logger`.
    /// The label can represent an application, a sub-system, or even a datatype.
    ///
    /// This initializer provides an escape hatch in case the global default logging backend implementation (set up
    /// using `LoggingSystem.bootstrap`) is not appropriate for this particular logger.
    ///
    /// - parameters:
    ///     - label: An identifier for the creator of a `Logger`.
    ///     - factory: A closure that creates a non-standard `LogHandler`.
    public init(label: String, factory: (String) -> any LogHandler) {
        self = Logger(label: label, factory(label))
    }

    /// Creates a logger using the label that identifies the creator of the logger or a non-standard log handler.
    ///
    /// The `label` should identify the creator of the `Logger`.
    /// The label can represent an application, a sub-system, or even a datatype.
    ///
    /// This initializer provides an escape hatch in case the global default logging backend implementation (set up
    /// using `LoggingSystem.bootstrap`) is not appropriate for this particular logger.
    ///
    /// - parameters:
    ///     - label: An identifier for the creator of a `Logger`.
    ///     - factory: A closure that creates a non-standard `LogHandler`.
    public init(label: String, factory: (String, Logger.MetadataProvider?) -> any LogHandler) {
        self = Logger(label: label, factory(label, LoggingSystem.metadataProvider))
    }

    /// Creates a logger using the label that identifies the creator of the logger or a non-standard log handler.
    ///
    /// The `label` should identify the creator of the `Logger`.
    /// The label can represent an application, a sub-system, or even a datatype.
    ///
    /// - Parameters:
    ///   - label: An identifier for the creator of a `Logger`.
    ///   - metadataProvider: The custom metadata provider this logger should invoke,
    ///   instead of the system wide bootstrapped one, when a log statement is about to be emitted.
    public init(label: String, metadataProvider: MetadataProvider) {
        self = Logger(
            label: label,
            factory: { label in
                var handler = LoggingSystem.factory(label, metadataProvider)
                handler.metadataProvider = metadataProvider
                return handler
            }
        )
    }
}

extension Logger.Level {
    internal var naturalIntegralValue: Int {
        switch self {
        case .trace:
            return 0
        case .debug:
            return 1
        case .info:
            return 2
        case .notice:
            return 3
        case .warning:
            return 4
        case .error:
            return 5
        case .critical:
            return 6
        }
    }
}

extension Logger.Level: Comparable {
    public static func < (lhs: Logger.Level, rhs: Logger.Level) -> Bool {
        lhs.naturalIntegralValue < rhs.naturalIntegralValue
    }
}

extension Logger.Level: CustomStringConvertible, LosslessStringConvertible {
    /// A textual representation of the log level.
    public var description: String {
        self.rawValue
    }

    /// Creates a log level from its textual representation.
    /// - Parameter description: A textual representation of the log level, case insensitive.
    public init?(_ description: String) {
        self.init(rawValue: description.lowercased())
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9687
// Then we could write it as follows and it would work under Swift 5 and not only 4 as it does currently:
// extension Logger.Metadata.Value: Equatable {
extension Logger.MetadataValue: Equatable {
    /// Returns a Boolean value that indicates whether two metadata values are equal.
    /// - Parameters:
    ///   - lhs: The first metadata value.
    ///   - rhs: The second metadata value.
    /// - Returns: Returns `true` if the metadata values are equivalent; otherwise `false`.
    public static func == (lhs: Logger.Metadata.Value, rhs: Logger.Metadata.Value) -> Bool {
        switch (lhs, rhs) {
        case (.string(let lhs), .string(let rhs)):
            return lhs == rhs
        case (.stringConvertible(let lhs), .stringConvertible(let rhs)):
            return lhs.description == rhs.description
        case (.array(let lhs), .array(let rhs)):
            return lhs == rhs
        case (.dictionary(let lhs), .dictionary(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

extension Logger {
    /// The content of log message.
    ///
    /// It is usually created using string literals.
    ///
    /// Example creating a `Logger.Message`:
    ///
    ///     let world: String = "world"
    ///     let myLogMessage: Logger.Message = "Hello \(world)"
    ///
    /// Most commonly, `Logger.Message`s appear simply as the parameter to a logging method such as:
    ///
    ///     logger.info("Hello \(world)")
    ///
    public struct Message: ExpressibleByStringLiteral, Equatable, CustomStringConvertible,
        ExpressibleByStringInterpolation
    {
        public typealias StringLiteralType = String

        private var value: String

        public init(stringLiteral value: String) {
            self.value = value
        }

        public var description: String {
            self.value
        }
    }
}

extension Logger {
    @inlinable
    internal static func currentModule(filePath: String = #file) -> String {
        let utf8All = filePath.utf8
        return filePath.utf8.lastIndex(of: UInt8(ascii: "/")).flatMap { lastSlash -> Substring? in
            utf8All[..<lastSlash].lastIndex(of: UInt8(ascii: "/")).map { secondLastSlash -> Substring in
                filePath[utf8All.index(after: secondLastSlash)..<lastSlash]
            }
        }.map {
            String($0)
        } ?? "n/a"
    }

    @inlinable
    internal static func currentModule(fileID: String = #fileID) -> String {
        let utf8All = fileID.utf8
        if let slashIndex = utf8All.firstIndex(of: UInt8(ascii: "/")) {
            return String(fileID[..<slashIndex])
        } else {
            return "n/a"
        }
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9686
extension Logger.MetadataValue: ExpressibleByStringLiteral {
    /// The type that represents a string literal.
    public typealias StringLiteralType = String

    /// Create a new metadata value from the string literal value that you provide.
    /// - Parameter value: The metadata value.
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9686
extension Logger.MetadataValue: CustomStringConvertible {
    /// A string representation of the metadata value.
    public var description: String {
        switch self {
        case .dictionary(let dict):
            return dict.mapValues { $0.description }.description
        case .array(let list):
            return list.map { $0.description }.description
        case .string(let str):
            return str
        case .stringConvertible(let repr):
            return repr.description
        }
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9687
extension Logger.MetadataValue: ExpressibleByStringInterpolation {}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9686
extension Logger.MetadataValue: ExpressibleByDictionaryLiteral {
    /// The type of a metadata value key.
    public typealias Key = String
    /// The type of the value for a metadata value.
    public typealias Value = Logger.Metadata.Value

    /// Create a new metadata value from the dictionary literal that you provide.
    /// - Parameter elements: A dictionary literal of metadata values.
    public init(dictionaryLiteral elements: (String, Logger.Metadata.Value)...) {
        self = .dictionary(.init(uniqueKeysWithValues: elements))
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9686
extension Logger.MetadataValue: ExpressibleByArrayLiteral {
    /// The type that the array literal element represents.
    public typealias ArrayLiteralElement = Logger.Metadata.Value

    /// Create a new metadata value from the array literal that you provide.
    /// - Parameter elements: A array literal of metadata values.
    public init(arrayLiteral elements: Logger.Metadata.Value...) {
        self = .array(elements)
    }
}

// MARK: - Sendable support helpers

extension Logger.MetadataValue: Sendable {}

// String interpolation support for AttributedMetadataValue
extension Logger.AttributedMetadataValue: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    /// Custom string interpolation that captures attributes from interpolated values.
    ///
    /// This enables syntax like:
    /// ```swift
    /// logger.info("User action", attributedMetadata: [
    ///     "user.id": "\(userId, attributes: { $0[MyAttribute.self] = .flagged })",
    ///     "action": "\(action)"
    /// ])
    /// ```
    public struct StringInterpolation: StringInterpolationProtocol, Sendable {
        @usableFromInline
        internal var output: String = ""

        @usableFromInline
        internal var attributes: Logger.MetadataValueAttributes = .init()

        public init(literalCapacity: Int, interpolationCount: Int) {
            self.output.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            self.output.append(literal)
        }

        /// Interpolation with a custom attributes closure.
        ///
        /// This allows setting arbitrary attributes inline:
        /// ```swift
        /// "\(userId, attributes: { $0[MyAttribute.self] = .flagged })"
        /// ```
        @inlinable
        public mutating func appendInterpolation<T>(
            _ value: T,
            attributes: @Sendable (inout Logger.MetadataValueAttributes) -> Void
        ) where T: CustomStringConvertible & Sendable {
            self.output.append(value.description)
            attributes(&self.attributes)
        }

        /// Plain interpolation without attributes.
        ///
        /// Attribute packages (like `LoggingAttributes`) can add overloads with attribute parameters.
        @inlinable
        public mutating func appendInterpolation<T>(
            _ value: T
        ) where T: CustomStringConvertible & Sendable {
            self.output.append(value.description)
        }

        @usableFromInline
        internal var result: (string: String, attributes: Logger.MetadataValueAttributes) {
            (self.output, self.attributes)
        }
    }

    /// Creates an attributed metadata value from a string literal.
    ///
    /// Defaults to empty attributes for ease of adoption.
    public init(stringLiteral value: String) {
        self.init(.string(value), attributes: Logger.MetadataValueAttributes())
    }

    /// Creates an attributed metadata value from string interpolation.
    ///
    /// The attributes are determined by the interpolation parameters.
    public init(stringInterpolation: StringInterpolation) {
        let result = stringInterpolation.result
        self.init(.string(result.string), attributes: result.attributes)
    }
}

extension Logger: Sendable {}
extension Logger.Level: Sendable {}
extension Logger.Message: Sendable {}
