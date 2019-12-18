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
#else
import Glibc
#endif

/// A `Logger` is the central type in `SwiftLog`. Its central function is to emit log messages using one of the methods
/// corresponding to a log level.
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
    ///    - metadata: One-off metadata to attach to this log message
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
                    file: String = #file, function: String = #function, line: UInt = #line) {
        if self.logLevel <= level {
            self.handler.log(level: level,
                             message: message(),
                             metadata: metadata(),
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
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func trace(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .trace, message(), metadata: metadata(), file: file, function: function, line: line)
    }

    /// Log a message passing with the `Logger.Level.debug` log level.
    ///
    /// If `.debug` is at least as severe as the `Logger`'s `logLevel`, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func debug(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .debug, message(), metadata: metadata(), file: file, function: function, line: line)
    }

    /// Log a message passing with the `Logger.Level.info` log level.
    ///
    /// If `.info` is at least as severe as the `Logger`'s `logLevel`, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func info(_ message: @autoclosure () -> Logger.Message,
                     metadata: @autoclosure () -> Logger.Metadata? = nil,
                     file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .info, message(), metadata: metadata(), file: file, function: function, line: line)
    }

    /// Log a message passing with the `Logger.Level.notice` log level.
    ///
    /// If `.notice` is at least as severe as the `Logger`'s `logLevel`, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func notice(_ message: @autoclosure () -> Logger.Message,
                       metadata: @autoclosure () -> Logger.Metadata? = nil,
                       file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .notice, message(), metadata: metadata(), file: file, function: function, line: line)
    }

    /// Log a message passing with the `Logger.Level.warning` log level.
    ///
    /// If `.warning` is at least as severe as the `Logger`'s `logLevel`, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func warning(_ message: @autoclosure () -> Logger.Message,
                        metadata: @autoclosure () -> Logger.Metadata? = nil,
                        file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .warning, message(), metadata: metadata(), file: file, function: function, line: line)
    }

    /// Log a message passing with the `Logger.Level.error` log level.
    ///
    /// If `.error` is at least as severe as the `Logger`'s `logLevel`, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func error(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .error, message(), metadata: metadata(), file: file, function: function, line: line)
    }

    /// Log a message passing with the `Logger.Level.critical` log level.
    ///
    /// `.critical` messages will always be logged.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#file`).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    @inlinable
    public func critical(_ message: @autoclosure () -> Logger.Message,
                         metadata: @autoclosure () -> Logger.Metadata? = nil,
                         file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .critical, message(), metadata: metadata(), file: file, function: function, line: line)
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
    /// lead to undefined behaviour, most likely a crash.
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
    ///  - prefer `logger.info("user selected colours", metadata: ["colors": ["\(user.topColor)", "\(user.secondColor)"]])`
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
        /// Appropriate for messages that contain information only when debugging a program.
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
    public struct Message: ExpressibleByStringLiteral,
        Equatable,
        CustomStringConvertible,
        ExpressibleByStringInterpolation {
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
/// The first `LogHandler` passed to the initialisation function of `MultiplexLogHandler` control the `logLevel` as
/// well as the `metadata` for this `LogHandler`. Any subsequent `LogHandler`s used to initialise a
/// `MultiplexLogHandler` are merely to emit the log message to another place.
public struct MultiplexLogHandler: LogHandler {
    private var handlers: [LogHandler]

    /// Create a `MultiplexLogHandler`.
    ///
    /// - parameters:
    ///    - handlers: An array of `LogHandler`s, each of which will receive the log messages sent to this `Logger`.
    ///                The array must not be empty.
    public init(_ handlers: [LogHandler]) {
        assert(!handlers.isEmpty)
        self.handlers = handlers
    }

    public var logLevel: Logger.Level {
        get {
            return self.handlers[0].logLevel
        }
        set {
            self.mutatingForEachHandler {
                $0.logLevel = newValue
            }
        }
    }

    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata?,
                    file: String, function: String, line: UInt) {
        self.handlers.forEach { handler in
            handler.log(level: level, message: message, metadata: metadata, file: file, function: function, line: line)
        }
    }

    public var metadata: Logger.Metadata {
        get {
            return self.handlers[0].metadata
        }
        set {
            self.mutatingForEachHandler { $0.metadata = newValue }
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.handlers[0].metadata[metadataKey]
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
            flockfile(self.file)
            defer {
                funlockfile(self.file)
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
                    file: String, function: String, line: UInt) {
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
