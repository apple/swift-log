import Foundation

public protocol LogEmitter {
    /// not called directly, only by the helper methods like `info(...)`
    func log(level: LogLevel, message: String, file: String, function: String, line: UInt)

    /// This adds diagnostic context to a place the concrete logger considers appropriate. Some loggers
    /// might not support this feature at all.
    subscript(diagnosticKey diagnosticKey: String) -> String? { get set }
    
    var logLevel: LogLevel { get set }
}

public struct Logger {
    @usableFromInline
    var emitter: LogEmitter

    internal init(_ emitter: LogEmitter) {
        self.emitter = emitter
    }

    @inlinable
    func log(level: LogLevel, message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        if self.logLevel <= level {
            self.emitter.log(level: level, message: message(), file: file, function: function, line: line)
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
            return self.emitter[diagnosticKey: diagnosticKey]
        }
        set {
            self.emitter[diagnosticKey: diagnosticKey] = newValue
        }
    }

    @inlinable
    public var logLevel: LogLevel {
        get {
            return self.emitter.logLevel
        }
        set {
            self.emitter.logLevel = newValue
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

extension LogLevel: Comparable {
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// The second most important type, this is where users will get a logger from.
public enum LoggerFactory {
    private static let lock = NSLock()
    private static var _factory: (String) -> LogEmitter = StdoutLogger.init
    public static var factory: (String) -> LogEmitter {
        get {
            return self.lock.withLock { self._factory }
        }
        set {
            self.lock.withLock {
                self._factory = newValue
            }
        }
    }

    // this is used to create a logger for a certain unit which might be a module, file, class/struct, function, whatever works for the concrete application. Systems that pass the logger explicitly would not use this function.
    public static func make(identifier: String) -> Logger {
        return Logger(self.factory(identifier))
    }
}

/// Ships with the logging module, really boring just prints something using the `print` function
final public class StdoutLogger: LogEmitter {
    
    private let lock = NSLock()
    private var context: [String: String] = [:] {
        didSet {
            if self.context.isEmpty {
                self.prettyContext = ""
            } else {
                self.prettyContext = " \(self.context.description)"
            }
        }
    }
    private var prettyContext: String = ""
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
    

    public init(identifier: String) {
    }

    public func log(level: LogLevel, message: String, file: String, function: String, line: UInt) {
        if level >= self.logLevel {
            print("\(message)\(self.prettyContext)")
        }
    }
    
    public subscript(diagnosticKey diagnosticKey: String) -> String? {
        get {
            return self.lock.withLock { self.context[diagnosticKey] }
        }
        set {
            self.lock.withLock { self.context[diagnosticKey] = newValue }
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
