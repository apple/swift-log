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
public struct FileLogHandler: LogHandler {
    private var handler: CommonLogHandler
    private let defaultLogLevel: Logger.Level
    private let fileHandler = FileHandler()

    public init(label: String) {
        self.init(label: label, defaultLogLevel: .info)
    }

    public init(label: String, defaultLogLevel: Logger.Level) {
        self.handler = CommonLogHandler(label: label)
        self.defaultLogLevel = defaultLogLevel
    }

    public func log(level: Logger.Level, message: String, metadata: Logger.Metadata?, error: Error?, file: StaticString, function: StaticString, line: UInt) {
        self.handler.log(level: level, message: message, metadata: metadata, error: error) { text in
            self.fileHandler._write(text)
        }
    }

    public var logLevel: Logger.Level {
        get { return self.handler.logLevel ?? self.defaultLogLevel }
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
        write(self.fd, text + "\n", text.utf8.count + 1)
    }
}
