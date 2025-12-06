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

#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import CRT
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Android)
@preconcurrency import Android
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#else
#error("Unsupported runtime")
#endif

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
    /// - parameters:
    ///    - level: The severity level of the `message`.
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
        if self.logLevel <= level {
            self.handler.log(
                level: level,
                message: message(),
                metadata: metadata(),
                source: source() ?? Logger.currentModule(fileID: (file)),
                file: file,
                function: function,
                line: line
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
        self.log(level: level, message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
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
        self.log(
            level: .trace,
            message(),
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
        self.log(
            level: .debug,
            message(),
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
        self.log(
            level: .info,
            message(),
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
        self.log(
            level: .notice,
            message(),
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
        self.log(
            level: .warning,
            message(),
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
        self.log(
            level: .error,
            message(),
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
        self.log(
            level: .critical,
            message(),
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
}

/// The logging system is a global facility where you can configure the default logging backend implementation.
///
/// `LoggingSystem` is set up just once in a given program to set up the desired logging backend implementation.
/// The default behavior, if you don't define otherwise, sets the ``LogHandler`` to use a ``StreamLogHandler`` that presents its output to `STDOUT`.
///
/// You can configure that handler to present the output to `STDERR` instead using the following code:
///
/// ```swift
/// LoggingSystem.bootstrap(StreamLogHandler.standardError)
/// ```
///
/// The default (``StreamLogHandler``) is intended to be a convenience.
/// For production applications, implement the ``LogHandler`` protocol directly, or use a community-maintained backend.
public enum LoggingSystem {
    private static let _factory = FactoryBox(
        { label, _ in StreamLogHandler.standardError(label: label) },
        violationErrorMesage: "logging system can only be initialized once per process."
    )
    private static let _metadataProviderFactory = MetadataProviderBox(
        nil,
        violationErrorMesage: "logging system can only be initialized once per process."
    )

    #if DEBUG
    private static let _warnOnceBox: WarnOnceBox = WarnOnceBox()
    #endif

    /// A one-time configuration function that globally selects the implementation for your desired logging backend.
    ///
    /// >  Warning:
    /// > `bootstrap` can be called at maximum once in any given program, calling it more than once will
    /// > lead to undefined behavior, most likely a crash.
    ///
    /// - parameters:
    ///     - factory: A closure that provides a ``Logger`` label identifier and produces an instance of the ``LogHandler``.
    @preconcurrency
    public static func bootstrap(_ factory: @escaping @Sendable (String) -> any LogHandler) {
        self._factory.replace(
            { label, _ in
                factory(label)
            },
            validate: true
        )
    }

    /// A one-time configuration function that globally selects the implementation for your desired logging backend.
    ///
    /// >  Warning:
    /// > `bootstrap` can be called at maximum once in any given program, calling it more than once will
    /// > lead to undefined behavior, most likely a crash.
    ///
    /// - parameters:
    ///     - metadataProvider: The `MetadataProvider` used to inject runtime-generated metadata from the execution context.
    ///     - factory: A closure that provides a ``Logger`` label identifier and produces an instance of the ``LogHandler``.
    @preconcurrency
    public static func bootstrap(
        _ factory: @escaping @Sendable (String, Logger.MetadataProvider?) -> any LogHandler,
        metadataProvider: Logger.MetadataProvider?
    ) {
        self._metadataProviderFactory.replace(metadataProvider, validate: true)
        self._factory.replace(factory, validate: true)
    }

    // for our testing we want to allow multiple bootstrapping
    internal static func bootstrapInternal(_ factory: @escaping @Sendable (String) -> any LogHandler) {
        self._metadataProviderFactory.replace(nil, validate: false)
        self._factory.replace(
            { label, _ in
                factory(label)
            },
            validate: false
        )
    }

    // for our testing we want to allow multiple bootstrapping
    internal static func bootstrapInternal(
        _ factory: @escaping @Sendable (String, Logger.MetadataProvider?) -> any LogHandler,
        metadataProvider: Logger.MetadataProvider?
    ) {
        self._metadataProviderFactory.replace(metadataProvider, validate: false)
        self._factory.replace(factory, validate: false)
    }

    fileprivate static var factory: (String, Logger.MetadataProvider?) -> any LogHandler {
        { label, metadataProvider in
            self._factory.underlying(label, metadataProvider)
        }
    }

    /// System wide ``Logger/MetadataProvider`` that was configured during the logging system's `bootstrap`.
    ///
    /// When creating a ``Logger`` using the plain ``Logger/init(label:)`` initializer, this metadata provider
    /// will be provided to it.
    ///
    /// When using custom log handler factories, make sure to provide the bootstrapped metadata provider to them,
    /// or the metadata will not be filled in automatically using the provider on log-sites. While using a custom
    /// factory to avoid using the bootstrapped metadata provider may sometimes be useful, usually it will lead to
    /// un-expected behavior, so make sure to always propagate it to your handlers.
    public static var metadataProvider: Logger.MetadataProvider? {
        self._metadataProviderFactory.underlying
    }

    #if DEBUG
    /// Used to warn only once about a specific ``LogHandler`` type when it does not support ``Logger/MetadataProvider``,
    /// but an attempt was made to set a metadata provider on such handler. In order to avoid flooding the system with
    /// warnings such warning is only emitted in debug mode, and even then at-most once for a handler type.
    internal static func warnOnceLogHandlerNotSupportedMetadataProvider<Handler: LogHandler>(
        _ type: Handler.Type
    ) -> Bool {
        self._warnOnceBox.warnOnceLogHandlerNotSupportedMetadataProvider(type: type)
    }
    #endif

    /// Protects an object such that it can only be accessed through a Reader-Writer lock.
    final class RWLockedValueBox<Value: Sendable>: @unchecked Sendable {
        private let lock = ReadWriteLock()
        private var storage: Value

        init(initialValue: Value) {
            self.storage = initialValue
        }

        func withReadLock<Result>(_ operation: (Value) -> Result) -> Result {
            self.lock.withReaderLock {
                operation(self.storage)
            }
        }

        func withWriteLock<Result>(_ operation: (inout Value) -> Result) -> Result {
            self.lock.withWriterLock {
                operation(&self.storage)
            }
        }
    }

    /// Protects an object by applying the constraints that it can only be accessed through a Reader-Writer lock
    /// and can only be updated once from the initial value given.
    private struct ReplaceOnceBox<BoxedType: Sendable> {
        private struct ReplaceOnce: Sendable {
            private var initialized = false
            private var _underlying: BoxedType
            private let violationErrorMessage: String

            mutating func replaceUnderlying(_ underlying: BoxedType, validate: Bool) {
                precondition(!validate || !self.initialized, self.violationErrorMessage)
                self._underlying = underlying
                self.initialized = true
            }

            var underlying: BoxedType {
                self._underlying
            }

            init(underlying: BoxedType, violationErrorMessage: String) {
                self._underlying = underlying
                self.violationErrorMessage = violationErrorMessage
            }
        }

        private let storage: RWLockedValueBox<ReplaceOnce>

        init(_ underlying: BoxedType, violationErrorMesage: String) {
            self.storage = .init(
                initialValue: ReplaceOnce(
                    underlying: underlying,
                    violationErrorMessage: violationErrorMesage
                )
            )
        }

        func replace(_ newUnderlying: BoxedType, validate: Bool) {
            self.storage.withWriteLock { $0.replaceUnderlying(newUnderlying, validate: validate) }
        }

        var underlying: BoxedType {
            self.storage.withReadLock { $0.underlying }
        }
    }

    private typealias FactoryBox = ReplaceOnceBox<
        @Sendable (_ label: String, _ provider: Logger.MetadataProvider?) -> any LogHandler
    >

    private typealias MetadataProviderBox = ReplaceOnceBox<Logger.MetadataProvider?>
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

/// A pseudo log handler that sends messages to multiple other log handlers.
///
/// ### Effective Logger.Level
///
/// When first initialized, the multiplex log handlers' log level is automatically set to the minimum of all the
/// provided log handlers.
/// This ensures that each of the handlers are able to log at their appropriate level
/// any log events they might be interested in.
///
/// Example:
/// If log handler `A` is logging at `.debug` level, and log handler `B` is logging at `.info` level, the log level of the constructed
/// `MultiplexLogHandler([A, B])` is set to `.debug`. This means that this handler will operate on debug messages,
/// while only logged by the underlying `A` log handler (since `B`'s log level is `.info`
/// and thus it would not actually log that log message).
///
/// If the log level is _set_ on a `Logger` backed by an `MultiplexLogHandler` the log level applies to *all*
/// underlying log handlers, allowing a logger to still select at what level it wants to log regardless of if the underlying
/// handler is a multiplex or a normal one. If for some reason one might want to not allow changing a log level of a specific
/// handler passed into the multiplex log handler, this is possible by wrapping it in a handler which ignores any log level changes.
///
/// ### Effective Logger.Metadata
///
/// Since a `MultiplexLogHandler` is a combination of multiple log handlers, the handling of metadata can be non-obvious.
/// For example, the underlying log handlers may have metadata of their own set before they are used to initialize the multiplex log handler.
///
/// The multiplex log handler acts purely as proxy and does not make any changes to underlying handler metadata other than
/// proxying writes that users made on a `Logger` instance backed by this handler.
///
/// Setting metadata is always proxied through to _all_ underlying handlers, meaning that if a modification like
/// `logger[metadataKey: "x"] = "y"` is made, all the underlying log handlers used to create the multiplex handler
/// observe this change.
///
/// Reading metadata from the multiplex log handler MAY need to pick one of conflicting values if the underlying log handlers
/// were previously initiated with metadata before passing them into the multiplex handler. The multiplex handler uses
/// the order in which the handlers were passed in during its initialization as a priority indicator - the first handler's
/// values are more important than the next handlers values, etc.
///
/// Example:
/// If the multiplex log handler was initiated with two handlers like this: `MultiplexLogHandler([handler1, handler2])`.
/// The handlers each have some already set metadata: `handler1` has metadata values for keys `one` and `all`, and `handler2`
/// has values for keys `two` and `all`.
///
/// A query through the multiplex log handler the key `one` naturally returns `handler1`'s value, and a query for `two`
/// naturally returns `handler2`'s value.
/// Querying for the key `all` will return `handler1`'s value, as that handler has a high priority,
/// as indicated by its earlier position in the initialization, than the second handler.
/// The same rule applies when querying for the `metadata` property of the multiplex log handler; it constructs `Metadata` uniquing values.
public struct MultiplexLogHandler: LogHandler {
    private var handlers: [any LogHandler]
    private var effectiveLogLevel: Logger.Level
    /// This metadata provider runs after all metadata providers of the multiplexed handlers.
    private var _metadataProvider: Logger.MetadataProvider?

    /// Create a multiplex log handler.
    ///
    /// - parameters:
    ///    - handlers: An array of `LogHandler`s, each of which will receive the log messages sent to this `Logger`.
    ///                The array must not be empty.
    public init(_ handlers: [any LogHandler]) {
        assert(!handlers.isEmpty, "MultiplexLogHandler.handlers MUST NOT be empty")
        self.handlers = handlers
        self.effectiveLogLevel = handlers.map { $0.logLevel }.min() ?? .trace
    }

    /// Create a multiplex log handler with the metadata provider you provide.
    /// - Parameters:
    ///   - handlers: An array of `LogHandler`s, each of which will receive every log message sent to this `Logger`.
    ///    The array must not be empty.
    ///   - metadataProvider: The metadata provider that adds metadata to log messages for this handler.
    public init(_ handlers: [any LogHandler], metadataProvider: Logger.MetadataProvider?) {
        assert(!handlers.isEmpty, "MultiplexLogHandler.handlers MUST NOT be empty")
        self.handlers = handlers
        self.effectiveLogLevel = handlers.map { $0.logLevel }.min() ?? .trace
        self._metadataProvider = metadataProvider
    }

    /// Get or set the log level configured for this `Logger`.
    ///
    /// > Note: Changing the log level threshold for a logger only affects the instance of the `Logger` where you change it.
    /// > It is acceptable for logging backends to have some form of global log level override
    /// > that affects multiple or even all loggers. This means a change in `logLevel` to one `Logger` might in
    /// > certain cases have no effect.
    public var logLevel: Logger.Level {
        get {
            self.effectiveLogLevel
        }
        set {
            self.mutatingForEachHandler { $0.logLevel = newValue }
            self.effectiveLogLevel = newValue
        }
    }

    /// The metadata provider.
    public var metadataProvider: Logger.MetadataProvider? {
        get {
            if self.handlers.count == 1 {
                if let innerHandler = self.handlers.first?.metadataProvider {
                    if let multiplexHandlerProvider = self._metadataProvider {
                        return .multiplex([innerHandler, multiplexHandlerProvider])
                    } else {
                        return innerHandler
                    }
                } else if let multiplexHandlerProvider = self._metadataProvider {
                    return multiplexHandlerProvider
                } else {
                    return nil
                }
            } else {
                var providers: [Logger.MetadataProvider] = []
                let additionalMetadataProviderCount = (self._metadataProvider != nil ? 1 : 0)
                providers.reserveCapacity(self.handlers.count + additionalMetadataProviderCount)
                for handler in self.handlers {
                    if let provider = handler.metadataProvider {
                        providers.append(provider)
                    }
                }
                if let multiplexHandlerProvider = self._metadataProvider {
                    providers.append(multiplexHandlerProvider)
                }
                guard !providers.isEmpty else {
                    return nil
                }
                return .multiplex(providers)
            }
        }
        set {
            self.mutatingForEachHandler { $0.metadataProvider = newValue }
        }
    }

    /// Log a message using the log level and source that you provide.
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
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        for handler in self.handlers where handler.logLevel <= level {
            handler.log(
                level: level,
                message: message,
                metadata: metadata,
                source: source,
                file: file,
                function: function,
                line: line
            )
        }
    }
    /// Get or set the entire metadata storage as a dictionary.
    public var metadata: Logger.Metadata {
        get {
            var effective: Logger.Metadata = [:]
            // as a rough estimate we assume that the underlying handlers have a similar metadata count,
            // and we use the first one's current count to estimate how big of a dictionary we need to allocate:

            // !-safe, we always have at least one handler
            effective.reserveCapacity(self.handlers.first!.metadata.count)

            for handler in self.handlers {
                effective.merge(handler.metadata, uniquingKeysWith: { _, handlerMetadata in handlerMetadata })
                if let provider = handler.metadataProvider {
                    effective.merge(provider.get(), uniquingKeysWith: { _, provided in provided })
                }
            }
            if let provider = self._metadataProvider {
                effective.merge(provider.get(), uniquingKeysWith: { _, provided in provided })
            }

            return effective
        }
        set {
            self.mutatingForEachHandler { $0.metadata = newValue }
        }
    }

    /// Add, change, or remove a logging metadata item.
    ///
    /// > Note: Changing the logging metadata only affects the instance of the `Logger` where you change it.
    public subscript(metadataKey metadataKey: Logger.Metadata.Key) -> Logger.Metadata.Value? {
        get {
            for handler in self.handlers {
                if let value = handler[metadataKey: metadataKey] {
                    return value
                }
            }
            return nil
        }
        set {
            self.mutatingForEachHandler { $0[metadataKey: metadataKey] = newValue }
        }
    }

    private mutating func mutatingForEachHandler(_ mutator: (inout any LogHandler) -> Void) {
        for index in self.handlers.indices {
            mutator(&self.handlers[index])
        }
    }
}

#if canImport(WASILibc) || os(Android)
internal typealias CFilePointer = OpaquePointer
#else
internal typealias CFilePointer = UnsafeMutablePointer<FILE>
#endif

/// A wrapper to facilitate `print`-ing to stderr and stdio that
/// ensures access to the underlying `FILE` is locked to prevent
/// cross-thread interleaving of output.
internal struct StdioOutputStream: TextOutputStream, @unchecked Sendable {
    internal let file: CFilePointer
    internal let flushMode: FlushMode

    internal func write(_ string: String) {
        self.contiguousUTF8(string).withContiguousStorageIfAvailable { utf8Bytes in
            #if os(Windows)
            _lock_file(self.file)
            #elseif canImport(WASILibc)
            // no file locking on WASI
            #else
            flockfile(self.file)
            #endif
            defer {
                #if os(Windows)
                _unlock_file(self.file)
                #elseif canImport(WASILibc)
                // no file locking on WASI
                #else
                funlockfile(self.file)
                #endif
            }
            _ = fwrite(utf8Bytes.baseAddress!, 1, utf8Bytes.count, self.file)
            if case .always = self.flushMode {
                self.flush()
            }
        }!
    }

    /// Flush the underlying stream.
    internal func flush() {
        _ = fflush(self.file)
    }

    internal func contiguousUTF8(_ string: String) -> String.UTF8View {
        var contiguousString = string
        contiguousString.makeContiguousUTF8()
        return contiguousString.utf8
    }

    internal static let stderr = {
        // Prevent name clashes
        #if canImport(Darwin)
        let systemStderr = Darwin.stderr
        #elseif os(Windows)
        let systemStderr = CRT.stderr
        #elseif canImport(Glibc)
        let systemStderr = Glibc.stderr!
        #elseif canImport(Android)
        let systemStderr = Android.stderr
        #elseif canImport(Musl)
        let systemStderr = Musl.stderr!
        #elseif canImport(WASILibc)
        let systemStderr = WASILibc.stderr!
        #else
        #error("Unsupported runtime")
        #endif
        return StdioOutputStream(file: systemStderr, flushMode: .always)
    }()

    internal static let stdout = {
        // Prevent name clashes
        #if canImport(Darwin)
        let systemStdout = Darwin.stdout
        #elseif os(Windows)
        let systemStdout = CRT.stdout
        #elseif canImport(Glibc)
        let systemStdout = Glibc.stdout!
        #elseif canImport(Android)
        let systemStdout = Android.stdout
        #elseif canImport(Musl)
        let systemStdout = Musl.stdout!
        #elseif canImport(WASILibc)
        let systemStdout = WASILibc.stdout!
        #else
        #error("Unsupported runtime")
        #endif
        return StdioOutputStream(file: systemStdout, flushMode: .always)
    }()

    /// Defines the flushing strategy for the underlying stream.
    internal enum FlushMode {
        case undefined
        case always
    }
}

/// Stream log handler presents log messages to STDERR or STDOUT.
///
/// This is a simple implementation of `LogHandler` that directs
/// `Logger` output to either `stderr` or `stdout` via the factory methods.
///
/// Metadata is merged in the following order:
/// 1. Metadata set on the log handler itself is used as the base metadata.
/// 2. The handler's ``metadataProvider`` is invoked, overriding any existing keys.
/// 3. The per-log-statement metadata is merged, overriding any previously set keys.
public struct StreamLogHandler: LogHandler {
    internal typealias _SendableTextOutputStream = TextOutputStream & Sendable

    /// Creates a stream log handler that directs its output to STDOUT.
    public static func standardOutput(label: String) -> StreamLogHandler {
        StreamLogHandler(
            label: label,
            stream: StdioOutputStream.stdout,
            metadataProvider: LoggingSystem.metadataProvider
        )
    }

    /// Creates a stream log handler that directs its output to STDOUT using the metadata provider you provide.
    public static func standardOutput(label: String, metadataProvider: Logger.MetadataProvider?) -> StreamLogHandler {
        StreamLogHandler(label: label, stream: StdioOutputStream.stdout, metadataProvider: metadataProvider)
    }

    /// Creates a stream log handler that directs its output to STDERR.
    public static func standardError(label: String) -> StreamLogHandler {
        StreamLogHandler(
            label: label,
            stream: StdioOutputStream.stderr,
            metadataProvider: LoggingSystem.metadataProvider
        )
    }

    /// Creates a stream log handler that directs its output to STDERR using the metadata provider you provide.
    public static func standardError(label: String, metadataProvider: Logger.MetadataProvider?) -> StreamLogHandler {
        StreamLogHandler(label: label, stream: StdioOutputStream.stderr, metadataProvider: metadataProvider)
    }

    private let stream: any _SendableTextOutputStream
    private let label: String

    /// Get the log level configured for this `Logger`.
    ///
    /// > Note: Changing the log level threshold for a logger only affects the instance of the `Logger` where you change it.
    /// > It is acceptable for logging backends to have some form of global log level override
    /// > that affects multiple or even all loggers. This means a change in `logLevel` to one `Logger` might in
    /// > certain cases have no effect.
    public var logLevel: Logger.Level = .info

    /// The metadata provider.
    public var metadataProvider: Logger.MetadataProvider?

    private var prettyMetadata: String?
    /// Get or set the entire metadata storage as a dictionary.
    public var metadata = Logger.Metadata() {
        didSet {
            self.prettyMetadata = self.prettify(self.metadata)
        }
    }

    /// Add, change, or remove a logging metadata item.
    ///
    /// > Note: Changing the logging metadata only affects the instance of the `Logger` where you change it.
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            self.metadata[metadataKey]
        }
        set {
            self.metadata[metadataKey] = newValue
        }
    }

    // internal for testing only
    internal init(label: String, stream: any _SendableTextOutputStream) {
        self.init(label: label, stream: stream, metadataProvider: LoggingSystem.metadataProvider)
    }

    // internal for testing only
    internal init(label: String, stream: any _SendableTextOutputStream, metadataProvider: Logger.MetadataProvider?) {
        self.label = label
        self.stream = stream
        self.metadataProvider = metadataProvider
    }

    /// Log a message using the log level and source that you provide.
    ///
    /// - parameters:
    ///    - level: The log level to log the `message`.
    ///    - message: The message to be logged. The `message` parameter supports any string interpolation literal.
    ///    - explicitMetadata: One-off metadata to attach to this log message.
    ///    - source: The source this log message originates from. The value defaults
    ///              to the module that emits the log message.
    ///    - file: The file this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#fileID`.
    ///    - function: The function this log message originates from. There's usually no need to pass it explicitly, as
    ///                it defaults to `#function`.
    ///    - line: The line this log message originates from. There's usually no need to pass it explicitly, as it
    ///            defaults to `#line`.
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata explicitMetadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let effectiveMetadata = StreamLogHandler.prepareMetadata(
            base: self.metadata,
            provider: self.metadataProvider,
            explicit: explicitMetadata
        )

        let prettyMetadata: String?
        if let effectiveMetadata = effectiveMetadata {
            prettyMetadata = self.prettify(effectiveMetadata)
        } else {
            prettyMetadata = self.prettyMetadata
        }

        var stream = self.stream
        stream.write(
            "\(self.timestamp()) \(level)\(self.label.isEmpty ? "" : " ")\(self.label):\(prettyMetadata.map { " \($0)" } ?? "") [\(source)] \(message)\n"
        )
    }

    internal static func prepareMetadata(
        base: Logger.Metadata,
        provider: Logger.MetadataProvider?,
        explicit: Logger.Metadata?
    ) -> Logger.Metadata? {
        var metadata = base

        let provided = provider?.get() ?? [:]

        guard !provided.isEmpty || !((explicit ?? [:]).isEmpty) else {
            // all per-log-statement values are empty
            return nil
        }

        if !provided.isEmpty {
            metadata.merge(provided, uniquingKeysWith: { _, provided in provided })
        }

        if let explicit = explicit, !explicit.isEmpty {
            metadata.merge(explicit, uniquingKeysWith: { _, explicit in explicit })
        }

        return metadata
    }

    private func prettify(_ metadata: Logger.Metadata) -> String? {
        if metadata.isEmpty {
            return nil
        } else {
            return metadata.lazy.sorted(by: { $0.key < $1.key }).map { "\($0)=\($1)" }.joined(separator: " ")
        }
    }

    private func timestamp() -> String {
        var buffer = [Int8](repeating: 0, count: 255)
        #if os(Windows)
        var timestamp = __time64_t()
        _ = _time64(&timestamp)

        var localTime = tm()
        _ = _localtime64_s(&localTime, &timestamp)

        _ = strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", &localTime)
        #else
        var timestamp = time(nil)
        guard let localTime = localtime(&timestamp) else {
            return "<unknown>"
        }
        strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", localTime)
        #endif
        return buffer.withUnsafeBufferPointer {
            $0.withMemoryRebound(to: CChar.self) {
                String(cString: $0.baseAddress!)
            }
        }
    }
}

/// A no-operation log handler, used when no logging is required
public struct SwiftLogNoOpLogHandler: LogHandler {
    /// Creates a no-op log handler.
    public init() {}

    /// Creates a no-op log handler.
    public init(_: String) {}

    /// A proxy that discards every log message it receives.
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
    @inlinable public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        file: String,
        function: String,
        line: UInt
    ) {}

    /// A proxy that discards every log message that you provide.
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
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {}

    /// Add, change, or remove a logging metadata item.
    ///
    /// > Note: Changing the logging metadata only affects the instance of the `Logger` where you change it.
    @inlinable public subscript(metadataKey _: String) -> Logger.Metadata.Value? {
        get {
            nil
        }
        set {}
    }

    /// Get or set the entire metadata storage as a dictionary.
    @inlinable public var metadata: Logger.Metadata {
        get {
            [:]
        }
        set {}
    }

    /// Get or set the log level configured for this `Logger`.
    ///
    /// > Note: Changing the log level threshold for a logger only affects the instance of the `Logger` where you change it.
    /// > It is acceptable for logging backends to have some form of global log level override
    /// > that affects multiple or even all loggers. This means a change in `logLevel` to one `Logger` might in
    /// > certain cases have no effect.
    @inlinable public var logLevel: Logger.Level {
        get {
            .critical
        }
        set {}
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

// MARK: - Debug only warnings

#if DEBUG
/// Contains state to manage all kinds of "warn only once" warnings which the logging system may want to issue.
private final class WarnOnceBox: @unchecked Sendable {
    private let lock: Lock = Lock()
    private var warnOnceLogHandlerNotSupportedMetadataProviderPerType = Set<ObjectIdentifier>()

    func warnOnceLogHandlerNotSupportedMetadataProvider<Handler: LogHandler>(type: Handler.Type) -> Bool {
        self.lock.withLock {
            let id = ObjectIdentifier(type)
            let (inserted, _) = warnOnceLogHandlerNotSupportedMetadataProviderPerType.insert(id)
            return inserted  // warn about this handler type, it is the first time we encountered it
        }
    }
}
#endif

// MARK: - Sendable support helpers

extension Logger.MetadataValue: Sendable {}
extension Logger: Sendable {}
extension Logger.Level: Sendable {}
extension Logger.Message: Sendable {}
