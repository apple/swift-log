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

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#elseif os(Windows)
import MSVCRT
#else
import Glibc
#endif

/// A `Logger` is the central type in `SwiftLog`. Its central function is to emit log messages using one of the methods
/// corresponding to a log level.
///
/// `Logger`s are value types with respect to the `logLevel` and the `metadata` (as well as the immutable `label`
/// and the selected `LogHandler`). Therefore, `Logger`s are suitable to be passed around between libraries if you want
/// to preserve metadata across libraries.
///
/// The most basic usage of a `Logger` is
///
///     logger.info("Hello World!")
///
public struct Logger {
    @usableFromInline
    var handler: LogHandler

    /// An identifier of the creator of this `Logger`.
    public let label: String

    internal init(label: String, _ handler: LogHandler) {
        self.label = label
        self.handler = handler
    }
}

extension Logger {
    /// Log a message passing the log level as a parameter.
    ///
    /// If the `logLevel` passed to this method is more severe than the `Logger`'s `logLevel`, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - level: The log level to log `message` at. For the available log levels, see `Logger.Level`.
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log messages originates to. Currently, it defaults to the folder containing the
    ///              file that is emitting the log message, which usually is the module.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func log(level: Logger.Level,
                    _ message: @autoclosure () -> Logger.Message,
                    metadata: @autoclosure () -> Logger.Metadata? = nil,
                    source: @autoclosure () -> String? = nil,
                    file: String = #file, function: String = #function, line: UInt = #line) {
        if self.logLevel <= level {
            self.handler.log(level: level,
                             message: message(),
                             metadata: metadata(),
                             source: source() ?? Logger.currentModule(filePath: (file)),
                             file: file, function: function, line: line)
        }
    }

    /// Add, change, or remove a logging metadata item.
    ///
    /// - note: Logging metadata behaves as a value that means a change to the logging metadata will only affect the
    ///         very `Logger` it was changed on.
    @inlinable
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.handler[metadataKey: metadataKey]
        }
        set {
            self.handler[metadataKey: metadataKey] = newValue
        }
    }

    /// Get or set the log level configured for this `Logger`.
    ///
    /// - note: `Logger`s treat `logLevel` as a value. This means that a change in `logLevel` will only affect this
    ///         very `Logger`. It it acceptable for logging backends to have some form of global log level override
    ///         that affects multiple or even all loggers. This means a change in `logLevel` to one `Logger` might in
    ///         certain cases have no effect.
    @inlinable
    public var logLevel: Logger.Level {
        get {
            return self.handler.logLevel
        }
        set {
            self.handler.logLevel = newValue
        }
    }
}

extension Logger {
    /// Log a message passing with the `Logger.Level.trace` log level.
    ///
    /// If `.trace` is at least as severe as the `Logger`'s `logLevel`, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - source: The source this log messages originates to. Currently, it defaults to the folder containing the
    ///              file that is emitting the log message, which usually is the module.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func trace(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .trace, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    /// Log a message passing with the `Logger.Level.debug` log level.
    ///
    /// If `.debug` is at least as severe as the `Logger`'s `logLevel`, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log messages originates to. Currently, it defaults to the folder containing the
    ///              file that is emitting the log message, which usually is the module.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func debug(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .debug, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    /// Log a message passing with the `Logger.Level.info` log level.
    ///
    /// If `.info` is at least as severe as the `Logger`'s `logLevel`, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log messages originates to. Currently, it defaults to the folder containing the
    ///              file that is emitting the log message, which usually is the module.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func info(_ message: @autoclosure () -> Logger.Message,
                     metadata: @autoclosure () -> Logger.Metadata? = nil,
                     source: @autoclosure () -> String? = nil,
                     file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .info, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    /// Log a message passing with the `Logger.Level.notice` log level.
    ///
    /// If `.notice` is at least as severe as the `Logger`'s `logLevel`, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log messages originates to. Currently, it defaults to the folder containing the
    ///              file that is emitting the log message, which usually is the module.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func notice(_ message: @autoclosure () -> Logger.Message,
                       metadata: @autoclosure () -> Logger.Metadata? = nil,
                       source: @autoclosure () -> String? = nil,
                       file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .notice, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    /// Log a message passing with the `Logger.Level.warning` log level.
    ///
    /// If `.warning` is at least as severe as the `Logger`'s `logLevel`, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log messages originates to. Currently, it defaults to the folder containing the
    ///              file that is emitting the log message, which usually is the module.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func warning(_ message: @autoclosure () -> Logger.Message,
                        metadata: @autoclosure () -> Logger.Metadata? = nil,
                        source: @autoclosure () -> String? = nil,
                        file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .warning, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    /// Log a message passing with the `Logger.Level.error` log level.
    ///
    /// If `.error` is at least as severe as the `Logger`'s `logLevel`, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log messages originates to. Currently, it defaults to the folder containing the
    ///              file that is emitting the log message, which usually is the module.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func error(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .error, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    /// Log a message passing with the `Logger.Level.critical` log level.
    ///
    /// `.critical` messages will always be logged.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log messages originates to. Currently, it defaults to the folder containing the
    ///              file that is emitting the log message, which usually is the module.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func critical(_ message: @autoclosure () -> Logger.Message,
                         metadata: @autoclosure () -> Logger.Metadata? = nil,
                         source: @autoclosure () -> String? = nil,
                         file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .critical, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }
}

/// The `LoggingSystem` is a global facility where the default logging backend implementation (`LogHandler`) can be
/// configured. `LoggingSystem` is set up just once in a given program to set up the desired logging backend
/// implementation.
public enum LoggingSystem {
    fileprivate static let lock = ReadWriteLock()
    fileprivate static var factory: (String) -> LogHandler = StreamLogHandler.standardOutput
    fileprivate static var initialized = false

    /// `bootstrap` is a one-time configuration function which globally selects the desired logging backend
    /// implementation. `bootstrap` can be called at maximum once in any given program, calling it more than once will
    /// lead to undefined behavior, most likely a crash.
    ///
    /// - parameters:
    ///     - factory: A closure that given a `Logger` identifier, produces an instance of the `LogHandler`.
    public static func bootstrap(_ factory: @escaping (String) -> LogHandler) {
        self.lock.withWriterLock {
            precondition(!self.initialized, "logging system can only be initialized once per process.")
            self.factory = factory
            self.initialized = true
        }
    }

    // for our testing we want to allow multiple bootstraping
    internal static func bootstrapInternal(_ factory: @escaping (String) -> LogHandler) {
        self.lock.withWriterLock {
            self.factory = factory
        }
    }
}

extension Logger {
    /// `Metadata` is a typealias for `[String: Logger.MetadataValue]` the type of the metadata storage.
    public typealias Metadata = [String: MetadataValue]

    /// A logging metadata value. `Logger.MetadataValue` is string, array, and dictionary literal convertible.
    ///
    /// `MetadataValue` provides convenient conformances to `ExpressibleByStringInterpolation`,
    /// `ExpressibleByStringLiteral`, `ExpressibleByArrayLiteral`, and `ExpressibleByDictionaryLiteral` which means
    /// that when constructing `MetadataValue`s you should default to using Swift's usual literals.
    ///
    /// Examples:
    ///  - prefer `logger.info("user logged in", metadata: ["user-id": "\(user.id)"])` over
    ///    `..., metadata: ["user-id": .string(user.id.description)])`
    ///  - prefer `logger.info("user selected colors", metadata: ["colors": ["\(user.topColor)", "\(user.secondColor)"]])`
    ///    over `..., metadata: ["colors": .array([.string("\(user.topColor)"), .string("\(user.secondColor)")])`
    ///  - prefer `logger.info("nested info", metadata: ["nested": ["fave-numbers": ["\(1)", "\(2)", "\(3)"], "foo": "bar"]])`
    ///    over `..., metadata: ["nested": .dictionary(["fave-numbers": ...])])`
    public enum MetadataValue {
        /// A metadata value which is a `String`.
        ///
        /// Because `MetadataValue` implements `ExpressibleByStringInterpolation`, and `ExpressibleByStringLiteral`,
        /// you don't need to type `.string(someType.description)` you can use the string interpolation `"\(someType)"`.
        case string(String)

        /// A metadata value which is some `CustomStringConvertible`.
        case stringConvertible(CustomStringConvertible)

        /// A metadata value which is a dictionary from `String` to `Logger.MetadataValue`.
        ///
        /// Because `MetadataValue` implements `ExpressibleByDictionaryLiteral`, you don't need to type
        /// `.dictionary(["foo": .string("bar \(buz)")])`, you can just use the more natural `["foo": "bar \(buz)"]`.
        case dictionary(Metadata)

        /// A metadata value which is an array of `Logger.MetadataValue`s.
        ///
        /// Because `MetadataValue` implements `ExpressibleByArrayLiteral`, you don't need to type
        /// `.array([.string("foo"), .string("bar \(buz)")])`, you can just use the more natural `["foo", "bar \(buz)"]`.
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

        /// Appropriate for messages that contain information normally of use only when
        /// debugging a program.
        case debug

        /// Appropriate for informational messages.
        case info

        /// Appropriate for conditions that are not error conditions, but that may require
        /// special handling.
        case notice

        /// Appropriate for messages that are not error conditions, but more severe than
        /// `.notice`.
        case warning

        /// Appropriate for error conditions.
        case error

        /// Appropriate for critical error conditions that usually require immediate
        /// attention.
        ///
        /// When a `critical` message is logged, the logging backend (`LogHandler`) is free to perform
        /// more heavy-weight operations to capture system state (such as capturing stack traces) to facilitate
        /// debugging.
        case critical
    }

    /// Construct a `Logger` given a `label` identifying the creator of the `Logger`.
    ///
    /// The `label` should identify the creator of the `Logger`. This can be an application, a sub-system, or even
    /// a datatype.
    ///
    /// - parameters:
    ///     - label: An identifier for the creator of a `Logger`.
    public init(label: String) {
        self = LoggingSystem.lock.withReaderLock { Logger(label: label, LoggingSystem.factory(label)) }
    }

    /// Construct a `Logger` given a `label` identifying the creator of the `Logger` or a non-standard `LogHandler`.
    ///
    /// The `label` should identify the creator of the `Logger`. This can be an application, a sub-system, or even
    /// a datatype.
    ///
    /// This initializer provides an escape hatch in case the global default logging backend implementation (set up
    /// using `LoggingSystem.bootstrap` is not appropriate for this particular logger.
    ///
    /// - parameters:
    ///     - label: An identifier for the creator of a `Logger`.
    ///     - factory: A closure creating non-standard `LogHandler`s.
    public init(label: String, factory: (String) -> LogHandler) {
        self = Logger(label: label, factory(label))
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
        return lhs.naturalIntegralValue < rhs.naturalIntegralValue
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9687
// Then we could write it as follows and it would work under Swift 5 and not only 4 as it does currently:
// extension Logger.Metadata.Value: Equatable {
extension Logger.MetadataValue: Equatable {
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
    /// `Logger.Message` represents a log message's text. It is usually created using string literals.
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
    public struct Message: ExpressibleByStringLiteral, Equatable, CustomStringConvertible, ExpressibleByStringInterpolation {
        public typealias StringLiteralType = String

        private var value: String

        public init(stringLiteral value: String) {
            self.value = value
        }

        public var description: String {
            return self.value
        }
    }
}

/// A pseudo-`LogHandler` that can be used to send messages to multiple other `LogHandler`s.
///
/// ### Effective Logger.Level
///
/// When first initialized the multiplex log handlers' log level is automatically set to the minimum of all the
/// passed in log handlers. This ensures that each of the handlers will be able to log at their appropriate level
/// any log events they might be interested in.
///
/// Example:
/// If log handler `A` is logging at `.debug` level, and log handler `B` is logging at `.info` level, the constructed
/// `MultiplexLogHandler([A, B])`'s effective log level will be set to `.debug`, meaning that debug messages will be
/// handled by this handler, while only logged by the underlying `A` log handler (since `B`'s log level is `.info`
/// and thus it would not actually log that log message).
///
/// If the log level is _set_ on a `Logger` backed by an `MultiplexLogHandler` the log level will apply to *all*
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
/// `logger[metadataKey: "x"] = "y"` is made, all underlying log handlers that this multiplex handler was initiated with
/// will observe this change.
///
/// Reading metadata from the multiplex log handler MAY need to pick one of conflicting values if the underlying log handlers
/// were already initiated with some metadata before passing them into the multiplex handler. The multiplex handler uses
/// the order in which the handlers were passed in during its initialization as a priority indicator - the first handler's
/// values are more important than the next handlers values, etc.
///
/// Example:
/// If the multiplex log handler was initiated with two handlers like this: `MultiplexLogHandler([handler1, handler2])`.
/// The handlers each have some already set metadata: `handler1` has metadata values for keys `one` and `all`, and `handler2`
/// has values for keys `two` and `all`.
///
/// A query through the multiplex log handler the key `one` naturally returns `handler1`'s value, and a query for `two`
/// naturally returns `handler2`'s value. Querying for the key `all` will return `handler1`'s value, as that handler was indicated
/// "more important" than the second handler. The same rule applies when querying for the `metadata` property of the
/// multiplex log handler - it constructs `Metadata` uniquing values.
public struct MultiplexLogHandler: LogHandler {
    private var handlers: [LogHandler]
    private var effectiveLogLevel: Logger.Level

    /// Create a `MultiplexLogHandler`.
    ///
    /// - parameters:
    ///    - handlers: An array of `LogHandler`s, each of which will receive the log messages sent to this `Logger`.
    ///                The array must not be empty.
    public init(_ handlers: [LogHandler]) {
        assert(!handlers.isEmpty, "MultiplexLogHandler.handlers MUST NOT be empty")
        self.handlers = handlers
        self.effectiveLogLevel = handlers.map { $0.logLevel }.min() ?? .trace
    }

    public var logLevel: Logger.Level {
        get {
            return self.effectiveLogLevel
        }
        set {
            self.mutatingForEachHandler { $0.logLevel = newValue }
            self.effectiveLogLevel = newValue
        }
    }

    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata?,
                    source: String,
                    file: String,
                    function: String,
                    line: UInt) {
        for handler in self.handlers where handler.logLevel <= level {
            handler.log(level: level, message: message, metadata: metadata, source: source, file: file, function: function, line: line)
        }
    }

    public var metadata: Logger.Metadata {
        get {
            var effectiveMetadata: Logger.Metadata = [:]
            // as a rough estimate we assume that the underlying handlers have a similar metadata count,
            // and we use the first one's current count to estimate how big of a dictionary we need to allocate:
            effectiveMetadata.reserveCapacity(self.handlers.first!.metadata.count) // !-safe, we always have at least one handler
            return self.handlers.reduce(into: effectiveMetadata) { effectiveMetadata, handler in
                effectiveMetadata.merge(handler.metadata, uniquingKeysWith: { l, _ in l })
            }
        }
        set {
            self.mutatingForEachHandler { $0.metadata = newValue }
        }
    }

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

    private mutating func mutatingForEachHandler(_ mutator: (inout LogHandler) -> Void) {
        for index in self.handlers.indices {
            mutator(&self.handlers[index])
        }
    }
}

/// A wrapper to facilitate `print`-ing to stderr and stdio that
/// ensures access to the underlying `FILE` is locked to prevent
/// cross-thread interleaving of output.
internal struct StdioOutputStream: TextOutputStream {
    internal let file: UnsafeMutablePointer<FILE>
    internal let flushMode: FlushMode

    internal func write(_ string: String) {
        string.withCString { ptr in
            #if os(Windows)
            _lock_file(self.file)
            #else
            flockfile(self.file)
            #endif
            defer {
                #if os(Windows)
                _unlock_file(self.file)
                #else
                funlockfile(self.file)
                #endif
            }
            _ = fputs(ptr, self.file)
            if case .always = self.flushMode {
                self.flush()
            }
        }
    }

    /// Flush the underlying stream.
    /// This has no effect when using the `.always` flush mode, which is the default
    internal func flush() {
        _ = fflush(self.file)
    }

    internal static let stderr = StdioOutputStream(file: systemStderr, flushMode: .always)
    internal static let stdout = StdioOutputStream(file: systemStdout, flushMode: .always)

    /// Defines the flushing strategy for the underlying stream.
    internal enum FlushMode {
        case undefined
        case always
    }
}

// Prevent name clashes
#if os(macOS) || os(tvOS) || os(iOS) || os(watchOS)
let systemStderr = Darwin.stderr
let systemStdout = Darwin.stdout
#elseif os(Windows)
let systemStderr = MSVCRT.stderr
let systemStdout = MSVCRT.stdout
#else
let systemStderr = Glibc.stderr!
let systemStdout = Glibc.stdout!
#endif

/// `StreamLogHandler` is a simple implementation of `LogHandler` for directing
/// `Logger` output to either `stderr` or `stdout` via the factory methods.
public struct StreamLogHandler: LogHandler {
    /// Factory that makes a `StreamLogHandler` to directs its output to `stdout`
    public static func standardOutput(label: String) -> StreamLogHandler {
        return StreamLogHandler(label: label, stream: StdioOutputStream.stdout)
    }

    /// Factory that makes a `StreamLogHandler` to directs its output to `stderr`
    public static func standardError(label: String) -> StreamLogHandler {
        return StreamLogHandler(label: label, stream: StdioOutputStream.stderr)
    }

    private let stream: TextOutputStream
    private let label: String

    public var logLevel: Logger.Level = .info

    private var prettyMetadata: String?
    public var metadata = Logger.Metadata() {
        didSet {
            self.prettyMetadata = self.prettify(self.metadata)
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[metadataKey]
        }
        set {
            self.metadata[metadataKey] = newValue
        }
    }

    // internal for testing only
    internal init(label: String, stream: TextOutputStream) {
        self.label = label
        self.stream = stream
    }

    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata?,
                    source: String,
                    file: String,
                    function: String,
                    line: UInt) {
        let prettyMetadata = metadata?.isEmpty ?? true
            ? self.prettyMetadata
            : self.prettify(self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }))

        var stream = self.stream
        stream.write("\(self.timestamp()) \(level) \(self.label) :\(prettyMetadata.map { " \($0)" } ?? "") \(message)\n")
    }

    private func prettify(_ metadata: Logger.Metadata) -> String? {
        return !metadata.isEmpty ? metadata.map { "\($0)=\($1)" }.joined(separator: " ") : nil
    }

    private func timestamp() -> String {
        var buffer = [Int8](repeating: 0, count: 255)
        var timestamp = time(nil)
        let localTime = localtime(&timestamp)
        strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", localTime)
        return buffer.withUnsafeBufferPointer {
            $0.withMemoryRebound(to: CChar.self) {
                String(cString: $0.baseAddress!)
            }
        }
    }
}

/// No operation LogHandler, used when no logging is required
public struct SwiftLogNoOpLogHandler: LogHandler {
    public init() {}

    @inlinable public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {}

    @inlinable public subscript(metadataKey _: String) -> Logger.Metadata.Value? {
        get {
            return nil
        }
        set {}
    }

    @inlinable public var metadata: Logger.Metadata {
        get {
            return [:]
        }
        set {}
    }

    @inlinable public var logLevel: Logger.Level {
        get {
            return .critical
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
                filePath[utf8All.index(after: secondLastSlash) ..< lastSlash]
            }
        }.map {
            String($0)
        } ?? "n/a"
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9686
extension Logger.MetadataValue: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9686
extension Logger.MetadataValue: CustomStringConvertible {
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
    public typealias Key = String
    public typealias Value = Logger.Metadata.Value

    public init(dictionaryLiteral elements: (String, Logger.Metadata.Value)...) {
        self = .dictionary(.init(uniqueKeysWithValues: elements))
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9686
extension Logger.MetadataValue: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Logger.Metadata.Value

    public init(arrayLiteral elements: Logger.Metadata.Value...) {
        self = .array(elements)
    }
}
