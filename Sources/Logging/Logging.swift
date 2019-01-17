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
    func log(level: Logging.Level, message: String, metadata: Logging.Metadata?, error: Error?, file: StaticString, function: StaticString, line: UInt)

    // This adds metadata to a place the concrete logger considers appropriate. Some loggers
    // might not support this feature at all.
    subscript(metadataKey _: String) -> Logging.Metadata.Value? { get set }

    // All available metatdata
    var metadata: Logging.Metadata { get set }

    // The log level
    var logLevel: Logging.Level { get set }
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
    func log(level: Logging.Level, message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        if self.logLevel <= level {
            self.handler.log(level: level, message: message(), metadata: metadata(), error: error, file: file, function: function, line: line)
        }
    }

    @inlinable
    public func trace(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .trace, message: message, metadata: metadata, error: error, file: file, function: function, line: line)
    }

    @inlinable
    public func debug(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .debug, message: message, metadata: metadata, error: error, file: file, function: function, line: line)
    }

    @inlinable
    public func info(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .info, message: message, metadata: metadata, error: error, file: file, function: function, line: line)
    }

    @inlinable
    public func warning(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .warning, message: message, metadata: metadata, error: error, file: file, function: function, line: line)
    }

    @inlinable
    public func error(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .error, message: message, metadata: metadata, error: error, file: file, function: function, line: line)
    }

    @inlinable
    public subscript(metadataKey metadataKey: String) -> Logging.Metadata.Value? {
        get {
            return self.handler[metadataKey: metadataKey]
        }
        set {
            self.handler[metadataKey: metadataKey] = newValue
        }
    }

    @inlinable
    public var metadata: Logging.Metadata {
        get {
            return self.handler.metadata
        }
        set {
            self.handler.metadata = newValue
        }
    }

    @inlinable
    public var logLevel: Logging.Level {
        get {
            return self.handler.logLevel
        }
        set {
            self.handler.logLevel = newValue
        }
    }
}

// This is the logging system itself, it's mostly used to obtain loggers and to set the type of the `LogHandler`
// implementation.
public enum Logging {
    private static let lock = ReadWriteLock()
    private static var _factory: (String) -> LogHandler = StdoutLogger.init

    // Configures which `LogHandler` to use in the application.
    public static func bootstrap(_ factory: @escaping (String) -> LogHandler) {
        self.lock.withWriterLock {
            self._factory = factory
        }
    }

    public static func make(_ label: String) -> Logger {
        return self.lock.withReaderLock { Logger(self._factory(label)) }
    }
}

extension Logging {
    public typealias Metadata = [String: MetadataValue]

    public enum MetadataValue {
        case string(String)
        case dictionary(Metadata)
        case array([Metadata.Value])
    }

    public enum Level: Int {
        case trace
        case debug
        case info
        case warning
        case error
    }
}

extension Logging.Level: Comparable {
    public static func < (lhs: Logging.Level, rhs: Logging.Level) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// Extension has to be done on explicit type rather than Logging.Metadata.Value as workaround for: https://bugs.swift.org/browse/SR-9687
// Then we could write it as follows and it would work under Swift 5 and not only 4 as it does currently:
// extension Logging.Metadata.Value: Equatable {
extension Logging.MetadataValue: Equatable {
    public static func ==(lhs: Logging.Metadata.Value, rhs: Logging.Metadata.Value) -> Bool {
        switch (lhs, rhs) {
        case (.string(let lhs), .string(let rhs)):
            return lhs == rhs
        case (.array(let lhs), .array(let rhs)):
            return lhs == rhs
        case (.dictionary(let lhs), .dictionary(let rhs)):
            return lhs == rhs
        default:
            return false
        }
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
    private let lock = Lock()
    private var handlers: [LogHandler]

    public init(handlers: [LogHandler]) {
        assert(handlers.count > 0)
        self.handlers = handlers
    }

    public var logLevel: Logging.Level {
        get {
            return self.handlers[0].logLevel
        }
        set {
            self.mutateHandlers { $0.logLevel = newValue }
        }
    }

    public func log(level: Logging.Level, message: String, metadata: Logging.Metadata?, error: Error?, file: StaticString, function: StaticString, line: UInt) {
        self.handlers.forEach { handler in
            handler.log(level: level, message: message, metadata: metadata, error: error, file: file, function: function, line: line)
        }
    }

    public var metadata: Logging.Metadata {
        get {
            return self.handlers[0].metadata
        }
        set {
            self.mutateHandlers { $0.metadata = newValue }
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logging.Metadata.Value? {
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
internal final class StdoutLogger: LogHandler {
    private let lock = Lock()

    public init(label: String) {}

    private var _logLevel: Logging.Level = .info
    public var logLevel: Logging.Level {
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
    private var _metadata = Logging.Metadata() {
        didSet {
            self.prettyMetadata = self.prettify(self._metadata)
        }
    }

    public func log(level: Logging.Level, message: String, metadata: Logging.Metadata?, error: Error?, file: StaticString, function: StaticString, line: UInt) {
        let prettyMetadata = metadata?.isEmpty ?? true ? self.prettyMetadata : self.prettify(self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }))
        print("\(self.timestamp()) \(level)\(prettyMetadata.map { " \($0)" } ?? "") \(message)\(error.map { " \($0)" } ?? "")")
    }

    public var metadata: Logging.Metadata {
        get {
            return self.lock.withLock { self._metadata }
        }
        set {
            self.lock.withLock { self._metadata = newValue }
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logging.Metadata.Value? {
        get {
            return self.lock.withLock { self._metadata[metadataKey] }
        }
        set {
            self.lock.withLock {
                self._metadata[metadataKey] = newValue
            }
        }
    }

    private func prettify(_ metadata: Logging.Metadata) -> String? {
        return !metadata.isEmpty ? metadata.map { "\($0)=\($1)" }.joined(separator: " ") : nil
    }

    private func timestamp() -> String {
        var buffer = [Int8](repeating: 0, count: 255)
        var timestamp = time(nil)
        let localTime = localtime(&timestamp)
        strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", localTime)
        return buffer.map { UInt8($0) }.withUnsafeBufferPointer { ptr in
            String.decodeCString(ptr.baseAddress, as: UTF8.self, repairingInvalidCodeUnits: true)
        }?.0 ?? "\(timestamp)"
    }
}
// Extension has to be done on explicit type rather than Logging.Metadata.Value as workaround for: https://bugs.swift.org/browse/SR-9687
extension Logging.MetadataValue: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension Logging.MetadataValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dictionary(let dict):
            return dict.mapValues { $0.description }.description
        case .array(let list):
            return list.map { $0.description }.description
        case .string(let str):
            return str
        }
    }
}

// Extension has to be done on explicit type rather than Logging.Metadata.Value as workaround for: https://bugs.swift.org/browse/SR-9687
extension Logging.MetadataValue: ExpressibleByStringInterpolation {
    #if !swift(>=5.0)
        public init(stringInterpolation strings: Logging.Metadata.Value...) {
            self = .string(strings.map { $0.description }.reduce("", +))
        }

    // TODO: seems not to exist on 5.0-DEVELOPMENT-SNAPSHOT-2019-01-16-a
    //        public init<T>(stringInterpolationSegment expr: T) {
    //            self = .string(String(stringInterpolationSegment: expr))
    //        }
    #endif
}

// Extension has to be done on explicit type rather than Logging.Metadata.Value as workaround for: https://bugs.swift.org/browse/SR-9687
extension Logging.MetadataValue: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = Logging.Metadata.Value

    public init(dictionaryLiteral elements: (String, Logging.Metadata.Value)...) {
        self = .dictionary(.init(uniqueKeysWithValues: elements))
    }
}

// Extension has to be done on explicit type rather than Logging.Metadata.Value as workaround for: https://bugs.swift.org/browse/SR-9687
extension Logging.MetadataValue: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Logging.Metadata.Value

    public init(arrayLiteral elements: Logging.Metadata.Value...) {
        self = .array(elements)
    }
}
