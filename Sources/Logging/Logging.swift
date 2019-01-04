import Foundation

/// This is the protocol a custom logger implements.
public protocol LogHandler {
    // This is the custom logger implementation's log function. A user would not invoke this but rather go through
    // `Logger`'s `info`, `error`, or `warning` functions.
    //
    // An implementation does not need to check the log level because that has been done before by `Logger` itself.
    func log(level: LogLevel, message: String, file: String, function: String, line: UInt)

    // This adds metadata to a place the concrete logger considers appropriate. Some loggers
    // might not support this feature at all.
    subscript(metadataKey _: LoggingMetadata.Key) -> LoggingMetadata.Value? { get set }

    // All available metatdata
    var metadata: LoggingMetadata? { get set }

    // The log level
    var logLevel: LogLevel { get set }
}

// This is the logger itself. It can either have value or reference semantics, depending on the `LogHandler`
// implementation.
public struct Logger {
    @usableFromInline
    var handler: LogHandler

    internal init(_ handler: LogHandler) {
        self.handler = handler
    }

    @inlinable
    func log(level: LogLevel, message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        if self.logLevel <= level {
            self.handler.log(level: level, message: message(), file: file, function: function, line: line)
        }
    }

    @inlinable
    public func trace(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .trace, message: message(), file: file, function: function, line: line)
    }

    @inlinable
    public func debug(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .debug, message: message(), file: file, function: function, line: line)
    }

    @inlinable
    public func info(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .info, message: message(), file: file, function: function, line: line)
    }

    @inlinable
    public func warn(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .warn, message: message(), file: file, function: function, line: line)
    }

    @inlinable
    public func error(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .error, message: message(), file: file, function: function, line: line)
    }

    @inlinable
    public subscript(metadataKey metadataKey: String) -> String? {
        get {
            return self.handler[metadataKey: metadataKey]
        }
        set {
            self.handler[metadataKey: metadataKey] = newValue
        }
    }

    @inlinable
    public var metadata: LoggingMetadata? {
        get {
            return self.handler.metadata
        }
        set {
            self.handler.metadata = newValue
        }
    }

    @inlinable
    public var logLevel: LogLevel {
        get {
            return self.handler.logLevel
        }
        set {
            self.handler.logLevel = newValue
        }
    }
}

public enum LogLevel: Int {
    case trace
    case debug
    case info
    case warn
    case error
}

public typealias LoggingMetadata = [String: String]

extension LogLevel: Comparable {
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// This is the logging system itself, it's mostly used to obtain loggers and to set the type of the `LogHandler`
// implementation.
public enum Logging {
    private static let lock = NSLock()
    private static var _factory: (String) -> LogHandler = StdoutLogger.init

    // Configures which `LogHandler` to use in the application.
    public static func bootstrap(_ factory: @escaping (String) -> LogHandler) {
        self.lock.withLock {
            self._factory = factory
        }
    }

    public static func make(_ label: String) -> Logger {
        return self.lock.withLock { Logger(self._factory(label)) }
    }
}

/// Ships with the logging module, used to multiplex to multiple logging handlers
public final class MultiplexLogging {
    private let factories: [(String) -> LogHandler]

    public init(_ factories: [(String) -> LogHandler]) {
        self.factories = factories
    }

    public func make(label: String) -> LogHandler {
        return MUXLogHandler(handlers: self.factories.map { $0(label) })
    }
}

private class MUXLogHandler: LogHandler {
    private let lock = NSLock()
    private var handlers: [LogHandler]

    public init(handlers: [LogHandler]) {
        assert(handlers.count > 0)
        self.handlers = handlers
    }

    public var logLevel: LogLevel {
        get {
            return self.handlers[0].logLevel
        }
        set {
            self.mutateHandlers { $0.logLevel = newValue }
        }
    }

    public func log(level: LogLevel, message: String, file: String, function: String, line: UInt) {
        self.handlers.forEach { handler in
            handler.log(level: level, message: message, file: file, function: function, line: line)
        }
    }

    public var metadata: LoggingMetadata? {
        get {
            return self.handlers[0].metadata
        }
        set {
            self.mutateHandlers { $0.metadata = newValue }
        }
    }

    public subscript(metadataKey metadataKey: String) -> String? {
        get {
            return self.handlers[0].metadata?[metadataKey]
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
public final class StdoutLogger: LogHandler {
    private let lock = NSLock()

    public init(label _: String) {}

    private var _logLevel: LogLevel = .info
    public var logLevel: LogLevel {
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
    private var _metadata: LoggingMetadata? {
        didSet {
            self.prettyMetadata = !(self._metadata?.isEmpty ?? true) ? self._metadata!.map { "\($0)=\($1)" }.joined(separator: " ") : nil
        }
    }

    public func log(level: LogLevel, message: String, file _: String, function _: String, line _: UInt) {
        if level >= self.logLevel {
            print("\(Date()) \(level)\(self.prettyMetadata.map { " \($0)" } ?? "") \(message)")
        }
    }

    public var metadata: LoggingMetadata? {
        get {
            return self.lock.withLock { self._metadata }
        }
        set {
            self.lock.withLock { self._metadata = newValue }
        }
    }

    public subscript(metadataKey metadataKey: String) -> String? {
        get {
            return self.lock.withLock { self._metadata?[metadataKey] }
        }
        set {
            self.lock.withLock {
                if nil == self._metadata {
                    self._metadata = [:]
                }
                self._metadata![metadataKey] = newValue
            }
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}
