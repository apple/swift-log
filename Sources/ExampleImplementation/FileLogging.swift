//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER IMPLEMENTATION LOOKS LIKE
//

import Foundation
import Logging
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    import Darwin
#else
    import Glibc
#endif

// this is a contrived example of a logging library implementation that writes logs to files
public final class FileLogging {
    private let defaultLogLevel: Logging.Level = .info
    private let fileHandler = FileHandler()

    public init() {}

    public func make(label: String) -> LogHandler {
        return Logger(label: label, defaultLogLevel: self.defaultLogLevel, fileHandler: self.fileHandler)
    }

    private struct Logger: LogHandler {
        private var logger: SimpleLogger
        private let defaultLogLevel: Logging.Level
        private let fileHandler: FileHandler

        public init(label: String, defaultLogLevel: Logging.Level, fileHandler: FileHandler) {
            self.logger = SimpleLogger(label: label)
            self.defaultLogLevel = defaultLogLevel
            self.fileHandler = fileHandler
        }

        public func log(level: Logging.Level, message: String, error: Error?, file: StaticString, function: StaticString, line: UInt) {
            self.logger.log(level: level, message: message, error: error) { text in
                self.fileHandler._write(text)
            }
        }

        public var logLevel: Logging.Level {
            get { return self.logger.logLevel ?? self.defaultLogLevel }
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

    private class FileHandler {
        let path: String
        let fd: Int32

        init() {
            self.path = "/tmp/log-\(UUID().uuidString).txt"
            self.fd = open(self.path, O_WRONLY | O_CREAT, 0o666)
            assert(self.fd > 0, "could not open \(self.path)")
            print("writing logs to \(self.path)")
        }

        deinit {
            if fd > 0 {
                close(fd)
            }
        }

        func _write(_ text: String) {
            write(self.fd, text, text.utf8.count)
        }
    }
}
