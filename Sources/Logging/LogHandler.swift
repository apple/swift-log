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

/// A log handler provides an implementation of a logging backend.
///
/// This type is an implementation detail and should not normally be used, unless you implement your own logging backend.
/// To use the SwiftLog API, please refer to the documentation of ``Logger``.
///
/// # Implementation requirements
///
/// To implement your own `LogHandler` you should respect a few requirements that are necessary so applications work
/// as expected, regardless of the selected `LogHandler` implementation.
///
/// - The ``LogHandler`` must be a `struct`.
/// - The metadata and `logLevel` properties must be implemented so that setting them on a `Logger` does not affect
///   other instances of `Logger`.
///
/// ### Treat log level & metadata as values
///
/// When developing your `LogHandler`, please make sure the following test works.
///
/// ```swift
/// @Test
/// func logHandlerValueSemantics() {
///     LoggingSystem.bootstrap(MyLogHandler.init)
///     var logger1 = Logger(label: "first logger")
///     logger1.logLevel = .debug
///     logger1[metadataKey: "only-on"] = "first"
///
///     var logger2 = logger1
///     logger2.logLevel = .error                  // Must not affect logger1
///     logger2[metadataKey: "only-on"] = "second" // Must not affect logger1
///
///     // These expectations must pass
///     #expect(logger1.logLevel == .debug)
///     #expect(logger2.logLevel == .error)
///     #expect(logger1[metadataKey: "only-on"] == "first")
///     #expect(logger2[metadataKey: "only-on"] == "second")
/// }
/// ```
///
/// ### Special cases
///
/// In certain special cases, the log level behaving like a value on `Logger` might not be what you want.
/// For example, you might want to set the log level across _all_ `Logger`s to `.debug` when a signal
/// (for example `SIGUSR1`) is received to be able to debug special failures in production.
/// This special case is acceptable but please create a solution specific to your `LogHandler` implementation to achieve that.
///
/// The following code illustrates an example implementation of this behavior.
/// On reception of the signal you would call
/// `LogHandlerWithGlobalLogLevelOverride.overrideGlobalLogLevel = .debug`, for example.
///
/// ```swift
/// import class Foundation.NSLock
///
/// public struct LogHandlerWithGlobalLogLevelOverride: LogHandler {
///     // The static properties hold the globally overridden
///     // log level (if overridden).
///     private static let overrideLock = NSLock()
///     private static var overrideLogLevel: Logger.Level? = nil
///
///     // this holds the log level if not overridden
///     private var _logLevel: Logger.Level = .info
///
///     // metadata storage
///     public var metadata: Logger.Metadata = [:]
///
///     public init(label: String) {
///         // [...]
///     }
///
///     public var logLevel: Logger.Level {
///         // When asked for the log level, check
///         // if it was globally overridden or not.
///         get {
///             LogHandlerWithGlobalLogLevelOverride.overrideLock.lock()
///             defer { LogHandlerWithGlobalLogLevelOverride.overrideLock.unlock() }
///             return LogHandlerWithGlobalLogLevelOverride.overrideLogLevel ?? self._logLevel
///         }
///         // Set the log level whenever asked
///         // (note: this might not have an effect if globally
///         // overridden).
///         set {
///             self._logLevel = newValue
///         }
///     }
///
///     public func log(
///         level: Logger.Level,
///         message: Logger.Message,
///         metadata: Logger.Metadata?,
///         source: String,
///         file: String,
///         function: String,
///         line: UInt) {
///         // [...]
///     }
///
///     public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
///         get {
///             return self.metadata[metadataKey]
///         }
///         set(newValue) {
///             self.metadata[metadataKey] = newValue
///         }
///     }
///
///     // This is the function to globally override the log level,
///     // it is not part of the `LogHandler` protocol.
///     public static func overrideGlobalLogLevel(_ logLevel: Logger.Level) {
///         LogHandlerWithGlobalLogLevelOverride.overrideLock.lock()
///         defer { LogHandlerWithGlobalLogLevelOverride.overrideLock.unlock() }
///         LogHandlerWithGlobalLogLevelOverride.overrideLogLevel = logLevel
///     }
/// }
/// ```
///
/// > Note: The above `LogHandler` still passes the 'log level is a value' test above it if the global log
/// > level has not been overridden. Most importantly, it passes the requirement listed above: A change to the log
/// > level on one `Logger` should not affect the log level of another `Logger` variable.
public protocol LogHandler: _SwiftLogSendableLogHandler {
    /// The metadata provider this log handler uses when a log statement is about to be emitted.
    ///
    /// A ``Logger/MetadataProvider`` may add a constant set of metadata,
    /// or use task-local values to pick up contextual metadata and add it to emitted logs.
    var metadataProvider: Logger.MetadataProvider? { get set }

    /// The library calls this method when a log handler must emit a log message.
    ///
    /// There is no need for the `LogHandler` to check if the `level` is above or
    /// below the configured `logLevel` as `Logger` already performed this check and
    /// determined that a message should be logged.
    ///
    /// - Parameters:
    ///   - level: The log level of the message.
    ///   - message: The message to log. To obtain a `String` representation call `message.description`.
    ///   - metadata: The metadata associated to this log message.
    ///   - source: The source where the log message originated, for example the logging module.
    ///   - file: The file this log message originates from.
    ///   - function: The function this log message originates from.
    ///   - line: The line this log message originates from.
    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    )

    /// SwiftLog 1.0 log compatibility method.
    ///
    /// Please do _not_ implement this method when you create a LogHandler implementation.
    /// Implement `log(level:message:metadata:source:file:function:line:)` instead.
    ///
    /// - Parameters:
    ///   - level: The log level of the message.
    ///   - message: The message to log. To obtain a `String` representation call `message.description`.
    ///   - metadata: The metadata associated to this log message.
    ///   - file: The file this log message originates from.
    ///   - function: The function this log message originates from.
    ///   - line: The line this log message originates from.
    @available(*, deprecated, renamed: "log(level:message:metadata:source:file:function:line:)")
    func log(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        metadata: Logging.Logger.Metadata?,
        file: String,
        function: String,
        line: UInt
    )

    /// Add, remove, or change the logging metadata.
    ///
    /// - note: `LogHandler`s must treat logging metadata as a value type. This means that the change in metadata must
    ///         only affect this very `LogHandler`.
    ///
    /// - parameters:
    ///    - metadataKey: The key for the metadata item
    subscript(metadataKey _: String) -> Logger.Metadata.Value? { get set }

    /// Get or set the entire metadata storage as a dictionary.
    ///
    /// - note: `LogHandler`s must treat logging metadata as a value type. This means that the change in metadata must
    ///         only affect this very `LogHandler`.
    var metadata: Logger.Metadata { get set }

    /// Get or set the configured log level.
    ///
    /// - note: `LogHandler`s must treat the log level as a value type. This means that the change in metadata must
    ///         only affect this very `LogHandler`. It is acceptable to provide some form of global log level override
    ///         that means a change in log level on a particular `LogHandler` might not be reflected in any
    ///        `LogHandler`.
    var logLevel: Logger.Level { get set }
}

extension LogHandler {
    /// Default implementation for a metadata provider that defaults to nil.
    ///
    /// This default exists in order to facilitate the source-compatible introduction of the `metadataProvider` protocol requirement.
    public var metadataProvider: Logger.MetadataProvider? {
        get {
            nil
        }
        set {
            #if DEBUG
            if LoggingSystem.warnOnceLogHandlerNotSupportedMetadataProvider(Self.self) {
                self.log(
                    level: .warning,
                    message:
                        "Attempted to set metadataProvider on \(Self.self) that did not implement support for them. Please contact the log handler maintainer to implement metadata provider support.",
                    metadata: nil,
                    source: "Logging",
                    file: #file,
                    function: #function,
                    line: #line
                )
            }
            #endif
        }
    }
}

extension LogHandler {
    /// A default implementation for a log message handler that forwards the source location for the message.
    /// - Parameters:
    ///   - level: The log level of the message.
    ///   - message: The message to log. To obtain a `String` representation call `message.description`.
    ///   - metadata: The metadata associated to this log message.
    ///   - source: The source where the log message originated, for example the logging module.
    ///   - file: The file this log message originates from.
    ///   - function: The function this log message originates from.
    ///   - line: The line this log message originates from.
    @available(*, deprecated, message: "You should implement this method instead of using the default implementation")
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        self.log(level: level, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    /// A default implementation for a log message handler.
    /// - Parameters:
    ///   - level: The log level of the message.
    ///   - message: The message to log. To obtain a `String` representation call `message.description`.
    ///   - metadata: The metadata associated to this log message.
    ///   - file: The file this log message originates from.
    ///   - function: The function this log message originates from.
    ///   - line: The line this log message originates from.
    @available(*, deprecated, renamed: "log(level:message:metadata:source:file:function:line:)")
    public func log(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        metadata: Logging.Logger.Metadata?,
        file: String,
        function: String,
        line: UInt
    ) {
        self.log(
            level: level,
            message: message,
            metadata: metadata,
            source: Logger.currentModule(filePath: file),
            file: file,
            function: function,
            line: line
        )
    }
}

// MARK: - Sendable support helpers

@preconcurrency public protocol _SwiftLogSendableLogHandler: Sendable {}
