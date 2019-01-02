//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER IMPLEMENTATION LOOKS LIKE
//

import Foundation
import Logging

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}

public struct ExampleValueLoggerImplementation: LogHandler {
    private var _metadata: LoggingMetadata = [:]

    public init(label _: String) {}

    public func log(level: LogLevel, message: String, file _: String, function _: String, line _: UInt) {
        print("\(self.formatLevel(level)): \(message) \(self.metadata?.description ?? "")")
    }

    private func formatLevel(_ level: LogLevel) -> String {
        switch level {
        case .error:
            return "ERRO"
        case .warn:
            return "WARN"
        case .info:
            return "info"
        case .debug:
            return "dbug"
        case .trace:
            return "trce"
        }
    }

    public subscript(metadataKey metadataKey: LoggingMetadata.Key) -> LoggingMetadata.Value? {
        get {
            return self._metadata[metadataKey]
        }
        set(newValue) {
            self._metadata[metadataKey] = newValue
        }
    }

    public var metadata: LoggingMetadata? {
        get {
            return self._metadata
        }
        set {
            if let newValue = newValue {
                self._metadata = newValue
            } else {
                self._metadata.removeAll()
            }
        }
    }

    public var logLevel: LogLevel = .info
}

public final class ExampleLoggerImplementation: LogHandler {
    private let formatter: DateFormatter
    private let label: String
    private let lock = NSLock()

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

    public init(label: String) {
        self.label = label
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = Calendar(identifier: .gregorian)
        self.formatter = formatter
    }

    private func formatLevel(_ level: LogLevel) -> String {
        switch level {
        case .error:
            return "ERRO"
        case .warn:
            return "WARN"
        case .info:
            return "info"
        case .debug:
            return "dbug"
        case .trace:
            return "trce"
        }
    }

    public func log(level: LogLevel, message: String, file _: String, function _: String, line _: UInt) {
        print("\(self.formatter.string(from: Date()))\(self.prettyMetadata.map { " \($0)" } ?? "") \(self.formatLevel(level)): \(message)")
    }

    private var prettyMetadata: String?
    private var _metadata: LoggingMetadata? {
        didSet {
            self.prettyMetadata = !(self._metadata?.isEmpty ?? true) ? self._metadata!.map { "\($0)=\($1)" }.joined(separator: " ") : nil
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
