//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER IMPLEMENTATION LOOKS LIKE
//

import Foundation
import Logging

// this is a contrived example of a logging library implementation that allows users to define log levels per logger label
// this example uses a simplistic in-memory config which can be changed at runtime via code
// real implementations could use external config files that can be changed outside the running program
public final class ConfigLogging {
    public var config = Config(defaultLogLevel: .info)

    public init() {}

    public func make(label: String) -> LogHandler {
        return Logger(label: label, config: self.config)
    }

    private struct Logger: LogHandler {
        private var logger: SimpleLogger
        private var config: Config

        public init(label: String, config: Config) {
            self.logger = SimpleLogger(label: label)
            self.config = config
        }

        public func log(level: Logging.Level, message: String, file: StaticString, function: StaticString, line _: UInt) {
            self.logger.log(level: level, message: message) { text in
                print(text)
            }
        }

        public var logLevel: Logging.Level {
            get { return self.logger.logLevel ?? self.config.get(key: self.logger.label) }
            set { self.logger.logLevel = newValue }
        }

        public var metadata: Logging.Metadata? {
            get { return self.logger.metadata }
            set { self.logger.metadata = newValue }
        }

        public subscript(metadataKey metadataKey: String) -> Logging.Metadata.Value? {
            get { return self.logger[metadataKey: metadataKey] }
            set { self.logger[metadataKey: metadataKey] = newValue }
        }
    }

    public class Config {
        private static let ALL = "*"

        private let lock = NSLock()
        private var storage = [String: Logging.Level]()
        private var defaultLogLevel: Logging.Level

        init(defaultLogLevel: Logging.Level) {
            self.defaultLogLevel = defaultLogLevel
        }

        func get(key: String) -> Logging.Level {
            return self.get(key) ?? self.get(Config.ALL) ?? self.defaultLogLevel
        }

        func get(_ key: String) -> Logging.Level? {
            return self.lock.withLock { self.storage[key] }
        }

        public func set(key: String, value: Logging.Level) {
            self.lock.withLock { self.storage[key] = value }
        }

        public func set(value: Logging.Level) {
            self.lock.withLock { self.storage[Config.ALL] = value }
        }

        public func clear() {
            self.lock.withLock { self.storage.removeAll() }
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
