import Foundation

public protocol LogHandler {
    /// not called directly, only by the helper methods like `info(...)`
    func log(level: LogLevel, message: String, file: String, function: String, line: UInt)

    /// This adds diagnostic context to a place the concrete logger considers appropriate. Some loggers
    /// might not support this feature at all.
    subscript(diagnosticKey _: LoggingMetadata.Key) -> LoggingMetadata.Value? { get set }

    var metadata: LoggingMetadata? { get set }

    var logLevel: LogLevel { get set }
}

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
    public subscript(diagnosticKey diagnosticKey: String) -> String? {
        get {
            return self.handler[diagnosticKey: diagnosticKey]
        }
        set {
            self.handler[diagnosticKey: diagnosticKey] = newValue
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

/// The second most important type, this is where users will get a logger from.
public enum Logging {
    private static let lock = NSLock()
    private static var _factory: (String) -> LogHandler = StdoutLogger.init

    public static func bootstrap(_ factory: @escaping (String) -> LogHandler) {
        self.lock.withLock {
            self._factory = factory
        }
    }

    // this is used to create a logger for a certain unit which might be a module, file, class/struct, function, whatever works for the concrete application. Systems that pass the logger explicitly would not use this function.
    public static func make(for object: Any.Type) -> Logger {
        return self.make(String(describing: object))
    }

    public static func make(_ label: String) -> Logger {
        return self.lock.withLock { Logger(self._factory(label)) }
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

    public subscript(diagnosticKey diagnosticKey: String) -> String? {
        get {
            return self.lock.withLock { self._metadata?[diagnosticKey] }
        }
        set {
            self.lock.withLock {
                if nil == self._metadata {
                    self._metadata = [:]
                }
                self._metadata![diagnosticKey] = newValue
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
