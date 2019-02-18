//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER IMPLEMENTATION LOOKS LIKE
//

import Foundation
import Logging

// this is a contrived example of a logging library implementation that allows users to define log levels per logger label
// this example uses a simplistic in-memory config which can be changed at runtime via code
// real implementations could use external config files that can be changed outside the running program
public class Config {
    private static let ALL = "*"

    private let lock = NSLock()
    private var storage = [String: Logger.Level]()
    private var defaultLogLevel: Logger.Level

    public init(defaultLogLevel: Logger.Level) {
        self.defaultLogLevel = defaultLogLevel
    }

    func get(key: String) -> Logger.Level {
        return self.get(key) ?? self.get(Config.ALL) ?? self.defaultLogLevel
    }

    func get(_ key: String) -> Logger.Level? {
        return self.lock.withLock { self.storage[key] }
    }

    public func set(key: String, value: Logger.Level) {
        self.lock.withLock { self.storage[key] = value }
    }

    public func set(value: Logger.Level) {
        self.lock.withLock { self.storage[Config.ALL] = value }
    }

    public func clear() {
        self.lock.withLock { self.storage.removeAll() }
    }
}

public struct ConfigLogHandler: LogHandler {
    private var handler: CommonLogHandler
    private var config: Config

    public init(label: String, config: Config) {
        self.handler = CommonLogHandler(label: label)
        self.config = config
    }

    public func log(level: Logger.Level, message: String, metadata: Logger.Metadata?, error: Error?, file: StaticString, function: StaticString, line: UInt) {
        self.handler.log(level: level, message: message, metadata: metadata, error: error) { text in
            print(text)
        }
    }

    public var logLevel: Logger.Level {
        get { return self.handler.logLevel ?? self.config.get(key: self.handler.label) }
        set { self.handler.logLevel = newValue }
    }

    public var metadata: Logger.Metadata {
        get { return self.handler.metadata }
        set { self.handler.metadata = newValue }
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get { return self.handler[metadataKey: metadataKey] }
        set { self.handler[metadataKey: metadataKey] = newValue }
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
