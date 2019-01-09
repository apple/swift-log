//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER IMPLEMENTATION LOOKS LIKE
//

import Foundation
import Logging

// this is a contrived example of a logging library implementation that writes logs to stdout
public final class SimpleLogging {
    private let defaultLogLevel = Logging.Level.info

    public init() {}

    public func make(label: String) -> LogHandler {
        return Logger(label: label, defaultLogLevel: self.defaultLogLevel)
    }

    private struct Logger: LogHandler {
        private var logger: SimpleLogger
        private let defaultLogLevel: Logging.Level

        public init(label: String, defaultLogLevel: Logging.Level) {
            self.logger = SimpleLogger(label: label)
            self.defaultLogLevel = defaultLogLevel
        }

        public func log(level: Logging.Level, message: String, metadata: Logging.Metadata?, error: Error?, file: StaticString, function: StaticString, line: UInt) {
            self.logger.log(level: level, message: message, metadata: metadata, error: error) { text in
                print(text)
            }
        }

        public var logLevel: Logging.Level {
            get { return self.logger.logLevel ?? self.defaultLogLevel }
            set { self.logger.logLevel = newValue }
        }

        public var metadata: Logging.Metadata {
            get { return self.logger.metadata }
            set { self.logger.metadata = newValue }
        }

        public subscript(metadataKey metadataKey: String) -> Logging.Metadata.Value? {
            get { return self.logger[metadataKey: metadataKey] }
            set { self.logger[metadataKey: metadataKey] = newValue }
        }
    }
}
