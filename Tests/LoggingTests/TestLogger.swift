import Foundation
@testable import Logging
import XCTest

internal struct TestLogging {
    private let _config = Config() // shared amonog loggers
    private let recorder = Recorder() // shared amonog loggers

    func make(label: String) -> LogHandler {
        return TestLoggger(label: label, config: self.config, recorder: self.recorder)
    }

    var config: Config { return self._config }
    var history: History { return self.recorder }
}

internal struct TestLoggger: LogHandler {
    private let logLevelLock = NSLock()
    private let metadataLock = NSLock()
    private let recorder: Recorder
    private let config: Config
    private var logger: Logger // the actual loggger

    let label: String
    init(label: String, config: Config, recorder: Recorder) {
        self.label = label
        self.config = config
        self.recorder = recorder
        self.logger = Logger(StdoutLogger(label: label))
        self.logger.logLevel = .trace
    }

    func log(level: LogLevel, message: String, file: String, function: String, line: UInt) {
        let metadata = self.metadata ?? MDC.global.metadata // use MDC unless set
        var l = logger // local copy since we gonna override its metadata
        l.metadata = metadata
        l.log(level: level, message: message, file: file, function: function, line: line)
        recorder.record(level: level, metadata: metadata, message: message)
    }

    private var _logLevel: LogLevel?
    var logLevel: LogLevel {
        get {
            // get from config unless set
            return self.logLevelLock.withLock { self._logLevel } ?? self.config.get(key: self.label)
        }
        set {
            self.logLevelLock.withLock { self._logLevel = newValue }
        }
    }

    // TODO: would be nice to deleagte to local copy of logger but StdoutLogger is a reference type. why?
    private var _metadata: LoggingMetadata?
    subscript(metadataKey metadataKey: LoggingMetadata.Key) -> LoggingMetadata.Value? {
        get {
            // return self.logger[metadataKey: metadataKey]
            return self.metadataLock.withLock { self._metadata?[metadataKey] }
        }
        set {
            // return logger[metadataKey: metadataKey] = newValue
            self.metadataLock.withLock {
                if nil == self._metadata {
                    self._metadata = LoggingMetadata()
                }
                self._metadata![metadataKey] = newValue
            }
        }
    }

    public var metadata: LoggingMetadata? {
        get {
            // return self.logger.metadata
            return self.metadataLock.withLock { self._metadata }
        }
        set {
            // self.logger.metadata = newValue
            self.metadataLock.withLock { self._metadata = newValue }
        }
    }
}

internal class Config {
    private static let ALL = "*"

    private let lock = NSLock()
    private var storage = [String: LogLevel]()

    func get(key: String) -> LogLevel {
        return self.get(key) ?? self.get(Config.ALL) ?? LogLevel.trace
    }

    func get(_ key: String) -> LogLevel? {
        guard let value = (self.lock.withLock { self.storage[key] }) else {
            return nil
        }
        return value
    }

    func set(key: String = Config.ALL, value: LogLevel) {
        self.lock.withLock { self.storage[key] = value }
    }

    func clear() {
        self.lock.withLock { self.storage.removeAll() }
    }
}

internal class Recorder: History {
    private let lock = NSLock()
    private var _entries = [LogEntry]()

    func record(level: LogLevel, metadata: LoggingMetadata?, message: String) {
        return self.lock.withLock {
            self._entries.append(LogEntry(level: level, metadata: metadata, message: message))
        }
    }

    var entries: [LogEntry] {
        return self.lock.withLock { self._entries }
    }
}

internal protocol History {
    var entries: [LogEntry] { get }
}

internal extension History {
    func atLevel(level: LogLevel) -> [LogEntry] {
        return self.entries.filter { entry in
            level == entry.level
        }
    }

    var trace: [LogEntry] {
        return self.atLevel(level: .trace)
    }

    var debug: [LogEntry] {
        return self.atLevel(level: .debug)
    }

    var info: [LogEntry] {
        return self.atLevel(level: .info)
    }

    var warn: [LogEntry] {
        return self.atLevel(level: .warn)
    }

    var error: [LogEntry] {
        return self.atLevel(level: .error)
    }
}

internal struct LogEntry {
    let level: LogLevel
    let metadata: LoggingMetadata?
    let message: String
}

extension History {
    func assertExist(level: LogLevel, metadata: LoggingMetadata?, message: String, file: StaticString = #file, line: UInt = #line) {
        let entry = self.find(level: level, metadata: metadata, message: message)
        XCTAssertNotNil(entry, "entry not found: \(level), \(String(describing: metadata)), \(message)", file: file, line: line)
    }

    func assertNotExist(level: LogLevel, metadata: LoggingMetadata?, message: String, file: StaticString = #file, line: UInt = #line) {
        let entry = self.find(level: level, metadata: metadata, message: message)
        XCTAssertNil(entry, "entry was found: \(level), \(String(describing: metadata)), \(message)]", file: file, line: line)
    }

    func find(level: LogLevel, metadata: LoggingMetadata?, message: String) -> LogEntry? {
        return self.entries.first { entry in
            entry.level == level && entry.message == message && entry.metadata ?? [:] == metadata ?? [:]
        }
    }
}

public class MDC {
    private let lock = NSLock()
    private var storage = [UInt32: LoggingMetadata]()

    public static var global = MDC()

    private init() {}

    public subscript(metadataKey: LoggingMetadata.Key) -> LoggingMetadata.Value? {
        get {
            return self.lock.withLock {
                self.storage[self.threadId]?[metadataKey]
            }
        }
        set {
            self.lock.withLock {
                if nil == self.storage[self.threadId] {
                    self.storage[self.threadId] = LoggingMetadata()
                }
                self.storage[self.threadId]![metadataKey] = newValue
            }
        }
    }

    public var metadata: LoggingMetadata? {
        return self.lock.withLock {
            self.storage[self.threadId]
        }
    }

    public func clear() {
        self.lock.withLock {
            self.storage.removeValue(forKey: self.threadId)
        }
    }

    public func with(metadata: LoggingMetadata?, _ body: () throws -> Void) rethrows {
        metadata?.forEach { self[$0] = $1 }
        defer {
            metadata?.keys.forEach { self[$0] = nil }
        }
        try body()
    }

    public func with<T>(metadata: LoggingMetadata?, _ body: () throws -> T) rethrows -> T {
        metadata?.forEach { self[$0] = $1 }
        defer {
            metadata?.keys.forEach { self[$0] = nil }
        }
        return try body()
    }

    // for testing
    internal func flush() {
        self.lock.withLock {
            self.storage.removeAll()
        }
    }

    private var threadId: UInt32 {
        return pthread_mach_thread_np(pthread_self())
    }
}

internal extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}

internal struct TestLibrary {
    private let logger = Logging.make("TestLibrary")
    private let queue = DispatchQueue(label: "TestLibrary")

    public init() {}

    public func doSomething() {
        self.logger.info("TestLibrary::doSomething")
    }

    public func doSomethingAsync(completion: @escaping () -> Void) {
        // libraries that use global loggers and async, need to make sure they propogate the
        // logging metadata when creating a new thread
        let metadata = MDC.global.metadata
        queue.asyncAfter(deadline: .now() + 0.1) {
            MDC.global.with(metadata: metadata) {
                self.logger.info("TestLibrary::doSomethingAsync")
                completion()
            }
        }
    }
}
