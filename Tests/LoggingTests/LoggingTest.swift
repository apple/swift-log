//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
@testable import Logging
import XCTest

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#else
import Glibc
#endif

class LoggingTest: XCTestCase {
    func testAutoclosure() throws {
        // bootstrap with our test logging impl
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal(logging.make)

        var logger = Logger(label: "test")
        logger.logLevel = .info
        logger.log(level: .debug, {
            XCTFail("debug should not be called")
            return "debug"
        }())
        logger.trace({
            XCTFail("trace should not be called")
            return "trace"
        }())
        logger.debug({
            XCTFail("debug should not be called")
            return "debug"
        }())
        logger.info({
            "info"
        }())
        logger.warning({
            "warning"
        }())
        logger.error({
            "error"
        }())
        XCTAssertEqual(3, logging.history.entries.count, "expected number of entries to match")
        logging.history.assertNotExist(level: .debug, message: "trace")
        logging.history.assertNotExist(level: .debug, message: "debug")
        logging.history.assertExist(level: .info, message: "info")
        logging.history.assertExist(level: .warning, message: "warning")
        logging.history.assertExist(level: .error, message: "error")
    }

    func testMultiplex() throws {
        // bootstrap with our test logging impl
        let logging1 = TestLogging()
        let logging2 = TestLogging()
        LoggingSystem.bootstrapInternal { MultiplexLogHandler([logging1.make(label: $0), logging2.make(label: $0)]) }

        var logger = Logger(label: "test")
        logger.logLevel = .warning
        logger.info("hello world?")
        logger[metadataKey: "foo"] = "bar"
        logger.warning("hello world!")
        logging1.history.assertNotExist(level: .info, message: "hello world?")
        logging2.history.assertNotExist(level: .info, message: "hello world?")
        logging1.history.assertExist(level: .warning, message: "hello world!", metadata: ["foo": "bar"])
        logging2.history.assertExist(level: .warning, message: "hello world!", metadata: ["foo": "bar"])
    }

    enum TestError: Error {
        case boom
    }

    func testDictionaryMetadata() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)

        var logger = Logger(label: "\(#function)")
        logger[metadataKey: "foo"] = ["bar": "buz"]
        logger[metadataKey: "empty-dict"] = [:]
        logger[metadataKey: "nested-dict"] = ["l1key": ["l2key": ["l3key": "l3value"]]]
        logger.info("hello world!")
        testLogging.history.assertExist(level: .info,
                                        message: "hello world!",
                                        metadata: ["foo": ["bar": "buz"],
                                                   "empty-dict": [:],
                                                   "nested-dict": ["l1key": ["l2key": ["l3key": "l3value"]]]])
    }

    func testListMetadata() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)

        var logger = Logger(label: "\(#function)")
        logger[metadataKey: "foo"] = ["bar", "buz"]
        logger[metadataKey: "empty-list"] = []
        logger[metadataKey: "nested-list"] = ["l1str", ["l2str1", "l2str2"]]
        logger.info("hello world!")
        testLogging.history.assertExist(level: .info,
                                        message: "hello world!",
                                        metadata: ["foo": ["bar", "buz"],
                                                   "empty-list": [],
                                                   "nested-list": ["l1str", ["l2str1", "l2str2"]]])
    }

    // Example of custom "box" which may be used to implement "render at most once" semantics
    // Not thread-safe, thus should not be shared across threads.
    internal class LazyMetadataBox: CustomStringConvertible {
        private var makeValue: (() -> String)?
        private var _value: String?

        public init(_ makeValue: @escaping () -> String) {
            self.makeValue = makeValue
        }

        /// This allows caching a value in case it is accessed via an by name subscript,
        // rather than as part of rendering all metadata that a LoggingContext was carrying
        public var value: String {
            if let f = self.makeValue {
                self._value = f()
                self.makeValue = nil
            }

            assert(self._value != nil, "_value MUST NOT be nil once `lazyValue` has run.")
            return self._value!
        }

        public var description: String {
            return "\(self.value)"
        }
    }

    func testStringConvertibleMetadata() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)
        var logger = Logger(label: "\(#function)")

        logger[metadataKey: "foo"] = .stringConvertible("raw-string")
        let lazyBox = LazyMetadataBox { "rendered-at-first-use" }
        logger[metadataKey: "lazy"] = .stringConvertible(lazyBox)
        logger.info("hello world!")
        testLogging.history.assertExist(level: .info,
                                        message: "hello world!",
                                        metadata: ["foo": .stringConvertible("raw-string"),
                                                   "lazy": .stringConvertible(LazyMetadataBox { "rendered-at-first-use" })])
    }

    private func dontEvaluateThisString(file: StaticString = #file, line: UInt = #line) -> Logger.Message {
        XCTFail("should not have been evaluated", file: file, line: line)
        return "should not have been evaluated"
    }

    func testAutoClosuresAreNotForcedUnlessNeeded() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)

        var logger = Logger(label: "\(#function)")
        logger.logLevel = .error

        logger.debug(self.dontEvaluateThisString(), metadata: ["foo": "\(self.dontEvaluateThisString())"])
        logger.debug(self.dontEvaluateThisString())
        logger.info(self.dontEvaluateThisString())
        logger.warning(self.dontEvaluateThisString())
        logger.log(level: .warning, self.dontEvaluateThisString())
    }

    func testLocalMetadata() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)

        var logger = Logger(label: "\(#function)")
        logger.info("hello world!", metadata: ["foo": "bar"])
        logger[metadataKey: "bar"] = "baz"
        logger[metadataKey: "baz"] = "qux"
        logger.warning("hello world!")
        logger.error("hello world!", metadata: ["baz": "quc"])
        testLogging.history.assertExist(level: .info, message: "hello world!", metadata: ["foo": "bar"])
        testLogging.history.assertExist(level: .warning, message: "hello world!", metadata: ["bar": "baz", "baz": "qux"])
        testLogging.history.assertExist(level: .error, message: "hello world!", metadata: ["bar": "baz", "baz": "quc"])
    }

    func testCustomFactory() {
        struct CustomHandler: LogHandler {
            func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {}

            subscript(metadataKey _: String) -> Logger.Metadata.Value? {
                get { return nil }
                set {}
            }

            var metadata: Logger.Metadata {
                get { return Logger.Metadata() }
                set {}
            }

            var logLevel: Logger.Level {
                get { return .info }
                set {}
            }
        }

        let logger1 = Logger(label: "foo")
        XCTAssertFalse(logger1.handler is CustomHandler, "expected non-custom log handler")
        let logger2 = Logger(label: "foo", factory: { _ in CustomHandler() })
        XCTAssertTrue(logger2.handler is CustomHandler, "expected custom log handler")
    }

    func testAllLogLevelsExceptCriticalCanBeBlocked() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)

        var logger = Logger(label: "\(#function)")
        logger.logLevel = .critical

        logger.trace("no")
        logger.debug("no")
        logger.info("no")
        logger.notice("no")
        logger.warning("no")
        logger.error("no")
        logger.critical("yes: critical")

        testLogging.history.assertNotExist(level: .trace, message: "no")
        testLogging.history.assertNotExist(level: .debug, message: "no")
        testLogging.history.assertNotExist(level: .info, message: "no")
        testLogging.history.assertNotExist(level: .notice, message: "no")
        testLogging.history.assertNotExist(level: .warning, message: "no")
        testLogging.history.assertNotExist(level: .error, message: "no")
        testLogging.history.assertExist(level: .critical, message: "yes: critical")
    }

    func testAllLogLevelsWork() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)

        var logger = Logger(label: "\(#function)")
        logger.logLevel = .trace

        logger.trace("yes: trace")
        logger.debug("yes: debug")
        logger.info("yes: info")
        logger.notice("yes: notice")
        logger.warning("yes: warning")
        logger.error("yes: error")
        logger.critical("yes: critical")

        testLogging.history.assertExist(level: .trace, message: "yes: trace")
        testLogging.history.assertExist(level: .debug, message: "yes: debug")
        testLogging.history.assertExist(level: .info, message: "yes: info")
        testLogging.history.assertExist(level: .notice, message: "yes: notice")
        testLogging.history.assertExist(level: .warning, message: "yes: warning")
        testLogging.history.assertExist(level: .error, message: "yes: error")
        testLogging.history.assertExist(level: .critical, message: "yes: critical")
    }

    func testLogMessageWithStringInterpolation() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)

        var logger = Logger(label: "\(#function)")
        logger.logLevel = .debug

        let someInt = Int.random(in: 23 ..< 42)
        logger.debug("My favourite number is \(someInt) and not \(someInt - 1)")
        testLogging.history.assertExist(level: .debug,
                                        message: "My favourite number is \(someInt) and not \(someInt - 1)" as String)
    }

    func testLoggingAString() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)

        var logger = Logger(label: "\(#function)")
        logger.logLevel = .debug

        let anActualString: String = "hello world!"
        // We can't stick an actual String in here because we expect a Logger.Message. If we want to log an existing
        // `String`, we can use string interpolation. The error you'll get trying to use the String directly is:
        //
        //     error: Cannot convert value of type 'String' to expected argument type 'Logger.Message'
        logger.debug("\(anActualString)")
        testLogging.history.assertExist(level: .debug, message: "hello world!")
    }

    func testMultiplexerIsValue() {
        let multi = MultiplexLogHandler([StreamLogHandler.standardOutput(label: "x"), StreamLogHandler.standardOutput(label: "y")])
        LoggingSystem.bootstrapInternal { _ in
            print("new multi")
            return multi
        }
        let logger1: Logger = {
            var logger = Logger(label: "foo")
            logger.logLevel = .debug
            logger[metadataKey: "only-on"] = "first"
            return logger
        }()
        XCTAssertEqual(.debug, logger1.logLevel)
        var logger2 = logger1
        logger2.logLevel = .error
        logger2[metadataKey: "only-on"] = "second"
        XCTAssertEqual(.error, logger2.logLevel)
        XCTAssertEqual(.debug, logger1.logLevel)
        XCTAssertEqual("first", logger1[metadataKey: "only-on"])
        XCTAssertEqual("second", logger2[metadataKey: "only-on"])
        logger1.error("hey")
    }

    func testLoggerWithGlobalOverride() {
        struct LogHandlerWithGlobalLogLevelOverride: LogHandler {
            // the static properties hold the globally overridden log level (if overridden)
            private static let overrideLock = Lock()
            private static var overrideLogLevel: Logger.Level?

            private let recorder: Recorder
            // this holds the log level if not overridden
            private var _logLevel: Logger.Level = .info

            // metadata storage
            var metadata: Logger.Metadata = [:]

            init(recorder: Recorder) {
                self.recorder = recorder
            }

            var logLevel: Logger.Level {
                // when we get asked for the log level, we check if it was globally overridden or not
                get {
                    return LogHandlerWithGlobalLogLevelOverride.overrideLock.withLock {
                        LogHandlerWithGlobalLogLevelOverride.overrideLogLevel
                    } ?? self._logLevel
                }
                // we set the log level whenever we're asked (note: this might not have an effect if globally
                // overridden)
                set {
                    self._logLevel = newValue
                }
            }

            func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?,
                     file: String, function: String, line: UInt) {
                self.recorder.record(level: level, metadata: metadata, message: message)
            }

            subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
                get {
                    return self.metadata[metadataKey]
                }
                set(newValue) {
                    self.metadata[metadataKey] = newValue
                }
            }

            // this is the function to globally override the log level, it is not part of the `LogHandler` protocol
            static func overrideGlobalLogLevel(_ logLevel: Logger.Level) {
                LogHandlerWithGlobalLogLevelOverride.overrideLock.withLock {
                    LogHandlerWithGlobalLogLevelOverride.overrideLogLevel = logLevel
                }
            }
        }

        let logRecorder = Recorder()
        LoggingSystem.bootstrapInternal { _ in
            LogHandlerWithGlobalLogLevelOverride(recorder: logRecorder)
        }

        var logger1 = Logger(label: "logger-\(#file):\(#line)")
        var logger2 = logger1
        logger1.logLevel = .warning
        logger1[metadataKey: "only-on"] = "first"
        logger2.logLevel = .error
        logger2[metadataKey: "only-on"] = "second"
        XCTAssertEqual(.error, logger2.logLevel)
        XCTAssertEqual(.warning, logger1.logLevel)
        XCTAssertEqual("first", logger1[metadataKey: "only-on"])
        XCTAssertEqual("second", logger2[metadataKey: "only-on"])

        logger1.notice("logger1, before")
        logger2.notice("logger2, before")

        LogHandlerWithGlobalLogLevelOverride.overrideGlobalLogLevel(.debug)

        logger1.notice("logger1, after")
        logger2.notice("logger2, after")

        logRecorder.assertNotExist(level: .notice, message: "logger1, before")
        logRecorder.assertNotExist(level: .notice, message: "logger2, before")
        logRecorder.assertExist(level: .notice, message: "logger1, after")
        logRecorder.assertExist(level: .notice, message: "logger2, after")
    }

    func testLogLevelCases() {
        let levels = Logger.Level.allCases
        XCTAssertEqual(7, levels.count)
    }

    func testLogLevelOrdering() {
        XCTAssertLessThan(Logger.Level.trace, Logger.Level.debug)
        XCTAssertLessThan(Logger.Level.trace, Logger.Level.info)
        XCTAssertLessThan(Logger.Level.trace, Logger.Level.notice)
        XCTAssertLessThan(Logger.Level.trace, Logger.Level.warning)
        XCTAssertLessThan(Logger.Level.trace, Logger.Level.error)
        XCTAssertLessThan(Logger.Level.trace, Logger.Level.critical)
        XCTAssertLessThan(Logger.Level.debug, Logger.Level.info)
        XCTAssertLessThan(Logger.Level.debug, Logger.Level.notice)
        XCTAssertLessThan(Logger.Level.debug, Logger.Level.warning)
        XCTAssertLessThan(Logger.Level.debug, Logger.Level.error)
        XCTAssertLessThan(Logger.Level.debug, Logger.Level.critical)
        XCTAssertLessThan(Logger.Level.info, Logger.Level.notice)
        XCTAssertLessThan(Logger.Level.info, Logger.Level.warning)
        XCTAssertLessThan(Logger.Level.info, Logger.Level.error)
        XCTAssertLessThan(Logger.Level.info, Logger.Level.critical)
        XCTAssertLessThan(Logger.Level.notice, Logger.Level.warning)
        XCTAssertLessThan(Logger.Level.notice, Logger.Level.error)
        XCTAssertLessThan(Logger.Level.notice, Logger.Level.critical)
        XCTAssertLessThan(Logger.Level.warning, Logger.Level.error)
        XCTAssertLessThan(Logger.Level.warning, Logger.Level.critical)
        XCTAssertLessThan(Logger.Level.error, Logger.Level.critical)
    }

    final class InterceptStream: TextOutputStream {
        var interceptedText: String?
        var strings = [String]()

        func write(_ string: String) {
            // This is a test implementation, a real implementation would include locking
            self.strings.append(string)
            self.interceptedText = (self.interceptedText ?? "") + string
        }
    }

    func testStreamLogHandlerWritesToAStream() {
        let interceptStream = InterceptStream()
        LoggingSystem.bootstrapInternal { _ in
            StreamLogHandler(label: "test", stream: interceptStream)
        }
        let log = Logger(label: "test")

        let testString = "my message is better than yours"
        log.critical("\(testString)")

        let messageSucceeded = interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(testString)

        XCTAssertTrue(messageSucceeded ?? false)
        XCTAssertEqual(interceptStream.strings.count, 1)
    }

    func testStreamLogHandlerOutputFormat() {
        let interceptStream = InterceptStream()
        let label = "testLabel"
        LoggingSystem.bootstrapInternal { _ in
            StreamLogHandler(label: label, stream: interceptStream)
        }
        let log = Logger(label: label)

        let testString = "my message is better than yours"
        log.critical("\(testString)")

        let pattern = "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+|-)\\d{4}\\s\(Logger.Level.critical)\\s\(label)\\s:\\s\(testString)$"

        let messageSucceeded = interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines).range(of: pattern, options: .regularExpression) != nil

        XCTAssertTrue(messageSucceeded)
        XCTAssertEqual(interceptStream.strings.count, 1)
    }

    func testStreamLogHandlerOutputFormatWithMetaData() {
        let interceptStream = InterceptStream()
        let label = "testLabel"
        LoggingSystem.bootstrapInternal { _ in
            StreamLogHandler(label: label, stream: interceptStream)
        }
        let log = Logger(label: label)

        let testString = "my message is better than yours"
        log.critical("\(testString)", metadata: ["test": "test"])

        let pattern = "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+|-)\\d{4}\\s\(Logger.Level.critical)\\s\(label)\\s:\\stest=test\\s\(testString)$"

        let messageSucceeded = interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines).range(of: pattern, options: .regularExpression) != nil

        XCTAssertTrue(messageSucceeded)
        XCTAssertEqual(interceptStream.strings.count, 1)
    }

    func testStdioOutputStreamFlush() {
        // flush on every statement
        self.withWriteReadFDsAndReadBuffer { writeFD, readFD, readBuffer in
            let logStream = StdioOutputStream(file: writeFD, flushMode: .always)
            LoggingSystem.bootstrapInternal { StreamLogHandler(label: $0, stream: logStream) }
            Logger(label: "test").critical("test")

            let size = read(readFD, readBuffer, 256)
            XCTAssertGreaterThan(size, -1, "expected flush")

            logStream.flush()
            let size2 = read(readFD, readBuffer, 256)
            XCTAssertEqual(size2, -1, "expected no flush")
        }
        // default flushing
        self.withWriteReadFDsAndReadBuffer { writeFD, readFD, readBuffer in
            let logStream = StdioOutputStream(file: writeFD, flushMode: .undefined)
            LoggingSystem.bootstrapInternal { StreamLogHandler(label: $0, stream: logStream) }
            Logger(label: "test").critical("test")

            let size = read(readFD, readBuffer, 256)
            XCTAssertEqual(size, -1, "expected no flush")

            logStream.flush()
            let size2 = read(readFD, readBuffer, 256)
            XCTAssertGreaterThan(size2, -1, "expected flush")
        }
    }

    func withWriteReadFDsAndReadBuffer(_ body: (UnsafeMutablePointer<FILE>, CInt, UnsafeMutablePointer<Int8>) -> Void) {
        var fds: [Int32] = [-1, -1]
        fds.withUnsafeMutableBufferPointer { ptr in
            let err = pipe(ptr.baseAddress!)
            XCTAssertEqual(err, 0, "pipe faild \(err)")
        }

        let writeFD = fdopen(fds[1], "w")
        let writeBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        defer {
            writeBuffer.deinitialize(count: 256)
            writeBuffer.deallocate()
        }

        var err = setvbuf(writeFD, writeBuffer, _IOFBF, 256)
        XCTAssertEqual(err, 0, "setvbuf faild \(err)")

        let readFD = fds[0]
        err = fcntl(readFD, F_SETFL, fcntl(readFD, F_GETFL) | O_NONBLOCK)
        XCTAssertEqual(err, 0, "fcntl faild \(err)")

        let readBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        defer {
            readBuffer.deinitialize(count: 256)
            readBuffer.deallocate()
        }

        // the actual test
        body(writeFD!, readFD, readBuffer)

        fds.forEach { close($0) }
    }
}
