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

/// This is the protocol a custom logger implements.
public protocol LogHandler {
    // This is the custom logger implementation's log function. A user would not invoke this but rather go through
    // `Logger`'s `info`, `error`, or `warning` functions.
    //
    // An implementation does not need to check the log level because that has been done before by `Logger` itself.
    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: StaticString, function: StaticString, line: UInt)

    // This adds metadata to a place the concrete logger considers appropriate. Some loggers
    // might not support this feature at all.
    subscript(metadataKey _: String) -> Logger.Metadata.Value? { get set }

    // All available metatdata
    var metadata: Logger.Metadata { get set }

    // The log level
    var logLevel: Logger.Level { get set }
}

// This is the logger itself. It can either have value or reference semantics, depending on the `LogHandler`
// implementation.
public struct Logger {
    @usableFromInline
    var handler: LogHandler
    public let label: String

    internal init(label: String, _ handler: LogHandler) {
        self.label = label
        self.handler = handler
    }
}

extension Logger {
    @inlinable
    public func log(level: Logger.Level, _ message: @autoclosure () -> Logger.Message, metadata: @autoclosure () -> Logger.Metadata? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        if self.logLevel >= level {
            self.handler.log(level: level, message: message(), metadata: metadata(), file: file, function: function, line: line)
        }
    }

    @inlinable
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.handler[metadataKey: metadataKey]
        }
        set {
            self.handler[metadataKey: metadataKey] = newValue
        }
    }

    @inlinable
    public var metadata: Logger.Metadata {
        get {
            return self.handler.metadata
        }
        set {
            self.handler.metadata = newValue
        }
    }

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
    @inlinable
    public func debug(_ message: @autoclosure () -> Logger.Message, metadata: @autoclosure () -> Logger.Metadata? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .debug, message(), metadata: metadata(), file: file, function: function, line: line)
    }

    @inlinable
    public func info(_ message: @autoclosure () -> Logger.Message, metadata: @autoclosure () -> Logger.Metadata? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .info, message(), metadata: metadata(), file: file, function: function, line: line)
    }

    @inlinable
    public func notice(_ message: @autoclosure () -> Logger.Message, metadata: @autoclosure () -> Logger.Metadata? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .notice, message(), metadata: metadata(), file: file, function: function, line: line)
    }

    @inlinable
    public func warning(_ message: @autoclosure () -> Logger.Message, metadata: @autoclosure () -> Logger.Metadata? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .warning, message(), metadata: metadata(), file: file, function: function, line: line)
    }

    @inlinable
    public func error(_ message: @autoclosure () -> Logger.Message, metadata: @autoclosure () -> Logger.Metadata? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .error, message(), metadata: metadata(), file: file, function: function, line: line)
    }

    @inlinable
    public func critical(_ message: @autoclosure () -> Logger.Message, metadata: @autoclosure () -> Logger.Metadata? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .critical, message(), metadata: metadata(), file: file, function: function, line: line)
    }

    @inlinable
    public func alert(_ message: @autoclosure () -> Logger.Message, metadata: @autoclosure () -> Logger.Metadata? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .alert, message(), metadata: metadata(), file: file, function: function, line: line)
    }

    @inlinable
    public func emergency(_ message: @autoclosure () -> Logger.Message, metadata: @autoclosure () -> Logger.Metadata? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .emergency, message(), metadata: metadata(), file: file, function: function, line: line)
    }
}

// This is the logging system itself, it's mostly used to obtain loggers and to set the type of the `LogHandler`
// implementation.
public enum LoggingSystem {
    fileprivate static let lock = ReadWriteLock()
    fileprivate static var factory: (String) -> LogHandler = StdoutLogHandler.init
    fileprivate static var initialized = false

    // Configures which `LogHandler` to use in the application.
    public static func bootstrap(_ factory: @escaping (String) -> LogHandler) {
        lock.withWriterLock {
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
    public typealias Metadata = [String: MetadataValue]

    public enum MetadataValue {
        case string(String)
        case stringConvertible(CustomStringConvertible)
        case dictionary(Metadata)
        case array([Metadata.Value])
    }

    public enum Level: Int {
        case debug = 7
        case info = 6
        case notice = 5
        case warning = 4
        case error = 3
        case critical = 2
        case alert = 1
        case emergency = 0
    }

    public init(label: String) {
        self = LoggingSystem.lock.withReaderLock { Logger(label: label, LoggingSystem.factory(label)) }
    }
    
    // this is to provide an escape hatch for situations one must use a custom factory instead of the gloabl one
    // we do not expect this API to be used in normal circumstances, so if you find yourself using it make sure its for a good reason
    public init(label: String, factory: (String) -> LogHandler) {
        self = Logger(label: label, factory(label))
    }
}

extension Logger.Level: Comparable {
    public static func < (lhs: Logger.Level, rhs: Logger.Level) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for: https://bugs.swift.org/browse/SR-9687
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

/// Ships with the logging module, used to multiplex to multiple logging handlers
public class MultiplexLogHandler: LogHandler {
    private let lock = Lock()
    private var handlers: [LogHandler]

    public init(_ handlers: [LogHandler]) {
        assert(handlers.count > 0)
        self.handlers = handlers
    }

    public var logLevel: Logger.Level {
        get {
            return self.handlers[0].logLevel
        }
        set {
            self.mutateHandlers { $0.logLevel = newValue }
        }
    }

    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: StaticString, function: StaticString, line: UInt) {
        self.handlers.forEach { handler in
            handler.log(level: level, message: message, metadata: metadata, file: file, function: function, line: line)
        }
    }

    public var metadata: Logger.Metadata {
        get {
            return self.handlers[0].metadata
        }
        set {
            self.mutateHandlers { $0.metadata = newValue }
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.handlers[0].metadata[metadataKey]
        }
        set {
            self.mutateHandlers { $0[metadataKey: metadataKey] = newValue }
        }
    }

    private func mutateHandlers(mutator: (inout LogHandler) -> Void) {
        var newHandlers = [LogHandler]()
        self.handlers.forEach {
            var handler = $0
            mutator(&handler)
            newHandlers.append(handler)
        }
        self.lock.withLock { self.handlers = newHandlers }
    }
}

/// Ships with the logging module, really boring just prints something using the `print` function
internal struct StdoutLogHandler: LogHandler {
    private let lock = Lock()

    public init(label: String) {}

    private var _logLevel: Logger.Level = .info
    public var logLevel: Logger.Level {
        get {
            return self.lock.withLock { self._logLevel }
        }
        set {
            self.lock.withLock {
                self._logLevel = newValue
            }
        }
    }

    private var prettyMetadata: String?
    private var _metadata = Logger.Metadata() {
        didSet {
            self.prettyMetadata = self.prettify(self._metadata)
        }
    }

    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: StaticString, function: StaticString, line: UInt) {
        let prettyMetadata = metadata?.isEmpty ?? true ? self.prettyMetadata : self.prettify(self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }))
        print("\(self.timestamp()) \(level):\(prettyMetadata.map { " \($0)" } ?? "") \(message)")
    }

    public var metadata: Logger.Metadata {
        get {
            return self.lock.withLock { self._metadata }
        }
        set {
            self.lock.withLock { self._metadata = newValue }
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.lock.withLock { self._metadata[metadataKey] }
        }
        set {
            self.lock.withLock {
                self._metadata[metadataKey] = newValue
            }
        }
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

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for: https://bugs.swift.org/browse/SR-9687
extension Logger.MetadataValue: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

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

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for: https://bugs.swift.org/browse/SR-9687
extension Logger.MetadataValue: ExpressibleByStringInterpolation {
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for: https://bugs.swift.org/browse/SR-9687
extension Logger.MetadataValue: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = Logger.Metadata.Value

    public init(dictionaryLiteral elements: (String, Logger.Metadata.Value)...) {
        self = .dictionary(.init(uniqueKeysWithValues: elements))
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for: https://bugs.swift.org/browse/SR-9687
extension Logger.MetadataValue: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Logger.Metadata.Value

    public init(arrayLiteral elements: Logger.Metadata.Value...) {
        self = .array(elements)
    }
}
