//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER IMPLEMENTATION LOOKS LIKE
//

import Foundation
import Logging

// this is a contrived example of a logging library implementation that writes logs to stdout
public final class SimpleLogging {
    private let defaultLogLevel = LogLevel.info

    public init() {}

    public func make(label: String) -> LogHandler {
        return Logger(label: label, defaultLogLevel: self.defaultLogLevel)
    }

    private struct Logger: LogHandler {
        private var logger: SimpleLogger
        private let defaultLogLevel: LogLevel

        public init(label: String, defaultLogLevel: LogLevel) {
            self.logger = SimpleLogger(label: label)
            self.defaultLogLevel = defaultLogLevel
        }

        public func log(level: LogLevel, message: String, file _: String, function _: String, line _: UInt) {
            self.logger.log(level: level, message: message) { text in
                print(text)
            }
        }

        public var logLevel: LogLevel {
            get { return self.logger.logLevel ?? self.defaultLogLevel }
            set { self.logger.logLevel = newValue }
        }

        public var metadata: LoggingMetadata? {
            get { return self.logger.metadata }
            set { self.logger.metadata = newValue }
        }

        public subscript(metadataKey metadataKey: String) -> String? {
            get { return self.logger[metadataKey: metadataKey] }
            set { self.logger[metadataKey: metadataKey] = newValue }
        }
    }
}
