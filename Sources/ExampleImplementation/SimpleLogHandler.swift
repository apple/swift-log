//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER IMPLEMENTATION LOOKS LIKE
//

import Foundation
import Logging

// this is a contrived example of a logging library implementation that writes logs to stdout
public struct SimpleLogHandler: LogHandler {
    private var handler: CommonLogHandler
    private let defaultLogLevel: Logger.Level

    public init(label: String) {
        self.init(label: label, defaultLogLevel: .info)
    }

    public init(label: String, defaultLogLevel: Logger.Level) {
        self.handler = CommonLogHandler(label: label)
        self.defaultLogLevel = defaultLogLevel
    }

    public func log(level: Logger.Level, message: String, metadata: Logger.Metadata?, error: Error?, file: StaticString, function: StaticString, line: UInt) {
        self.handler.log(level: level, message: message, metadata: metadata, error: error) { text in
            print(text)
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
