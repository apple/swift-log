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

/// A `LogHandler` is an implementation of a logging backend.
///
/// This type is an implementation detail and should not normally be used, unless implementing your own logging backend.
/// To use the SwiftLog API, please refer to the documentation of `Logger`.
///
/// # Implementation requirements
///
/// To implement your own `LogHandler` you should respect a few requirements that are necessary so applications work
/// as expected regardless of the selected `LogHandler` implementation.
///
/// - The `LogHandler` must be a `struct`.
/// - The metadata and `logLevel` properties must be implemented so that setting them on a `Logger` does not affect
///   other `Logger`s.
///
/// ### Treat log level & metadata as values
///
/// When developing your `LogHandler`, please make sure the following test works.
///
/// ```swift
/// LoggingSystem.bootstrap(MyLogHandler.init) // your LogHandler might have a different bootstrapping step
/// var logger1 = Logger(label: "first logger")
/// logger1.logLevel = .debug
/// logger1[metadataKey: "only-on"] = "first"
///
/// var logger2 = logger1
/// logger2.logLevel = .error                  // this must not override `logger1`'s log level
/// logger2[metadataKey: "only-on"] = "second" // this must not override `logger1`'s metadata
///
/// XCTAssertEqual(.debug, logger1.logLevel)
/// XCTAssertEqual(.error, logger2.logLevel)
/// XCTAssertEqual("first", logger1[metadataKey: "only-on"])
/// XCTAssertEqual("second", logger2[metadataKey: "only-on"])
/// ```
///
/// ### Special cases
///
/// In certain special cases, the log level behaving like a value on `Logger` might not be what you want. For example,
/// you might want to set the log level across _all_ `Logger`s to `.debug` when say a signal (eg. `SIGUSR1`) is received
/// to be able to debug special failures in production. This special case is acceptable but we urge you to create a
/// solution specific to your `LogHandler` implementation to achieve that. Please find an example implementation of this
/// behavior below, on reception of the signal you would call
/// `LogHandlerWithGlobalLogLevelOverride.overrideGlobalLogLevel = .debug`, for example.
///
/// ```swift
/// import class Foundation.NSLock
///
/// public struct LogHandlerWithGlobalLogLevelOverride: LogHandler {
///     // the static properties hold the globally overridden log level (if overridden)
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
///         // when we get asked for the log level, we check if it was globally overridden or not
///         get {
///             LogHandlerWithGlobalLogLevelOverride.overrideLock.lock()
///             defer { LogHandlerWithGlobalLogLevelOverride.overrideLock.unlock() }
///             return LogHandlerWithGlobalLogLevelOverride.overrideLogLevel ?? self._logLevel
///         }
///         // we set the log level whenever we're asked (note: this might not have an effect if globally
///         // overridden)
///         set {
///             self._logLevel = newValue
///         }
///     }
///
///     public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?,
///                     source: String, file: String, function: String, line: UInt) {
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
///     // this is the function to globally override the log level, it is not part of the `LogHandler` protocol
///     public static func overrideGlobalLogLevel(_ logLevel: Logger.Level) {
///         LogHandlerWithGlobalLogLevelOverride.overrideLock.lock()
///         defer { LogHandlerWithGlobalLogLevelOverride.overrideLock.unlock() }
///         LogHandlerWithGlobalLogLevelOverride.overrideLogLevel = logLevel
///     }
/// }
/// ```
///
/// Please note that the above `LogHandler` will still pass the 'log level is a value' test above it iff the global log
/// level has not been overridden. And most importantly it passes the requirement listed above: A change to the log
/// level on one `Logger` should not affect the log level of another `Logger` variable.
public protocol LogHandler {
    /// This method is called when a `LogHandler` must emit a log message. There is no need for the `LogHandler` to
    /// check if the `level` is above or below the configured `logLevel` as `Logger` already performed this check and
    /// determined that a message should be logged.
    ///
    /// - parameters:
    ///     - level: The log level the message was logged at.
    ///     - message: The message to log. To obtain a `String` representation call `message.description`.
    ///     - metadata: The metadata associated to this log message.
    ///     - source: The source where the log message originated, for example the logging module.
    ///     - file: The file the log message was emitted from.
    ///     - function: The function the log line was emitted from.
    ///     - line: The line the log message was emitted from.
    func log(level: Logger.Level,
             message: Logger.Message,
             metadata: Logger.Metadata?,
             source: String,
             file: String,
             function: String,
             line: UInt)

    /// SwiftLog 1.0 compatibility method. Please do _not_ implement, implement
    /// `log(level:message:metadata:source:file:function:line:)` instead.
    @available(*, deprecated, renamed: "log(level:message:metadata:source:file:function:line:)")
    func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, file: String, function: String, line: UInt)

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
    @available(*, deprecated, message: "You should implement this method instead of using the default implementation")
    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata?,
                    source: String,
                    file: String,
                    function: String,
                    line: UInt) {
        self.log(level: level, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    @available(*, deprecated, renamed: "log(level:message:metadata:source:file:function:line:)")
    public func log(level: Logging.Logger.Level, message: Logging.Logger.Message, metadata: Logging.Logger.Metadata?, file: String, function: String, line: UInt) {
        self.log(level: level,
                 message: message,
                 metadata: metadata,
                 source: Logger.currentModule(filePath: file),
                 file: file,
                 function: function,
                 line: line)
    }
}
