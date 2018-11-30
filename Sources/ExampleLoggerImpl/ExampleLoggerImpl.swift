//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER IMPLEMENTATION LOOKS LIKE
//

import Foundation
import ServerLoggerAPI

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}

public final class ExampleLoggerImplementation: Logger {
    private let formatter: DateFormatter
    private let identifier: String
    
    private let lock = NSLock()
    private var context: [String: String] = [:] {
        didSet {
            if self.context.isEmpty {
                self.prettyContext = ""
            } else {
                self.prettyContext = " \(self.context.description) @\(self.identifier)"
            }
        }
    }
    private var prettyContext: String
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
        self.prettyContext = ""
        self.identifier = identifier
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
    
    public func _log(level: LogLevel, message: String, file: String, function: String, line: UInt) {
        print("\(self.formatter.string(from: Date())) \(self.formatLevel(level)): \(message)\(self.prettyContext)")
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
