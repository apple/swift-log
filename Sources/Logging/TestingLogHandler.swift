import Foundation

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

public struct LogMessage: CustomStringConvertible {
    private static let timestampFormat = createTimestampFormat()

    private static func createTimestampFormat() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return dateFormatter
    }

    public let timestamp: Date
    public let label: String

    public let level: Logger.Level
    public let message: Logger.Message
    public let metadata: Logger.Metadata
    public let source: String

    public let file: String
    public let function: String
    public let line: UInt

    public var prettyMetadata: String {
        metadata.sorted(by: {
            $0.key < $1.key
        }).map {
            "\($0)=\($1)"
        }.joined(separator: " ")
    }

    public var description: String {
        "\(Self.timestampFormat.string(from: timestamp)) \(level) \(label) :\(prettyMetadata) [\(source)] \(message)"
    }

    public init(
        timestamp: Date = Date(),
        label: String = "nil",
        level: Logger.Level = .info,
        message: Logger.Message = .init(stringLiteral: ""),
        metadata: Logger.Metadata = [:],
        source: String = "nil",
        file: String = "nil",
        function: String = "nil",
        line: UInt = 0
    ) {
        self.timestamp = timestamp
        self.label = label
        self.level = level
        self.message = message
        self.metadata = metadata
        self.source = source
        self.file = file
        self.function = function
        self.line = line
    }

    // Easily check if log message matches certain characteristics:
    @available(macOS 13.0, *)
    public func match(
        label: String? = nil,
        level: Logger.Level? = nil,
        message: Regex<AnyRegexOutput>? = nil,
        metadata: [(Logger.Metadata.Element) -> Bool] = [],
        source: Regex<AnyRegexOutput>? = nil,
        file: Regex<AnyRegexOutput>? = nil,
        function: String? = nil,
        line: UInt? = nil
    ) -> Bool {
        if let label,
           self.label != label
        {
            return false
        }
        if let level,
           self.level != level
        {
            return false
        }
        if let message,
           !self.message.description.contains(message)
        {
            return false
        }
        for predicate in metadata {
            if !self.metadata.contains(where: predicate) {
                return false
            }
        }
        if let source,
           !self.source.contains(source)
        {
            return false
        }
        if let file,
           !self.file.contains(file)
        {
            return false
        }
        if let function,
           self.function != function
        {
            return false
        }
        if let line,
           self.line != line
        {
            return false
        }

        return true
    }
}

public struct TestingLogHandler: LogHandler, Sendable {
    public typealias Filter = (LogMessage) -> Bool

    public final class Container: @unchecked Sendable {
        // Guarded by queue:
        private var _messages: [LogMessage] = []

        private let queue: DispatchQueue

        private let filter: Filter

        init(_ filter: @escaping Filter) {
            self.filter = filter
            queue = DispatchQueue(label: "TestingLogHandler.Container:\(type(of: filter))")
        }

        public var messages: [LogMessage] {
            var result: [LogMessage] = []
            queue.sync {
                result = self._messages
            }
            return result
        }

        public func append(_ message: LogMessage) -> Bool {
            if filter(message) {
                queue.sync {
                    _messages.append(message)
                }
                return true
            }
            return false
        }

        public func reset() {
            queue.sync {
                self._messages = []
            }
        }
    }

    private static let queue = DispatchQueue(label: "TestingLogHandler")

    // Guarded by queue:
    private static var isInitialized = false
    // Guarded by queue:
    private static var logLevel: Logger.Level = .info
    // Guarded by queue:
    private static var _containers: [Weak<Container>] = []

    public static func bootstrap() {
        queue.sync {
            if !isInitialized {
                isInitialized = true
                LoggingSystem.bootstrap(Self.init)
            }
        }
    }

    internal static func bootstrapInternal() {
        queue.sync {
            if !isInitialized {
                isInitialized = true
                LoggingSystem.bootstrapInternal({ TestingLogHandler(label: $0) })
            }
        }
    }

    // Call in order to create a container of log messages which will only
    // contain messages that match the filter.
    public static func container(_ filter: @escaping Filter) -> Container {
        let container = Container(filter)
        queue.sync {
            if !isInitialized {
                fatalError("You must call TestingLogHandler.bootstrap() first. Ideally in your `override class func setUp() {...}")
            }
            Self._containers.append(Weak(container))
        }
        return container
    }

    // Override the default global log level (defaults to .info)
    public static func setLevel(_ level: Logger.Level) {
        queue.sync {
            logLevel = level
        }
    }

    // Introspect containers
    public static var containers: [Container] {
        var copy: [Weak<Container>]!
        queue.sync {
            copy = Self._containers
        }
        return copy.compactMap(\.value)
    }

    private let label: String
    private var _logLevel: Logger.Level? = nil

    // Defined in LogHandler protocol:
    public var metadata: Logger.Metadata = [:]
    public var logLevel: Logger.Level {
        // ALWAYS return .trace to ensure our log() method will be called. The
        // effectiveLogLevel is then used for if we should print to stderr:
        get { .trace }
        set {
            _logLevel = newValue
        }
    }

    public var effectiveLogLevel: Logger.Level {
        if let level = _logLevel {
            return level
        } else {
            var level: Logger.Level!
            Self.queue.sync {
                level = Self.logLevel
            }
            return level
        }
    }

    public init(label: String) {
        self.label = label
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        var metadata = metadata ?? [:]
        metadata.merge(self.metadata, uniquingKeysWith: { left, _ in left })

        let message = LogMessage(
            label: label,
            level: level,
            message: message,
            metadata: metadata,
            source: source,
            file: file,
            function: function,
            line: line
        )
        var inContainer = false
        for container in Self.containers {
            if container.append(message) {
                inContainer = true
            }
        }
        if !inContainer, effectiveLogLevel <= level {
            FileHandle.standardError.write(Data(message.description.utf8))
            FileHandle.standardError.write(Data("\n".utf8))
            fflush(stderr)
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            metadata[metadataKey]
        }
        set {
            metadata[metadataKey] = newValue
        }
    }
}

private class Weak<T: AnyObject> {
    weak var value: T?
    init(_ value: T) {
        self.value = value
    }
}
