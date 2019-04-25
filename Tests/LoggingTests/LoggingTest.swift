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

class LoggingTest: XCTestCase {
    func testAutoclosure() throws {
        // bootstrap with our test logging impl
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal(logging.make)

        var logger = Logger(label: "test")
        logger.logLevel = .info
        logger.log(level: .debug, { () -> String in
            XCTFail("trace should not be called")
            return "trace"
        }())
        #if swift(>=4.1.50)
        #if compiler(>=5.0)
        logger.debug({
            XCTFail("trace should not be called")
            return "trace"
        }())
        logger.debug({
            XCTFail("debug should not be called")
            return "debug"
        }())
        #else
        logger.debug({ () -> String in
            XCTFail("trace should not be called")
            return "trace"
            }())
        logger.debug({ () -> String in
            XCTFail("debug should not be called")
            return "debug"
            }())
        #endif
        #else
        logger.debug({ () -> String in
            XCTFail("trace should not be called")
            return "trace"
            }())
        logger.debug({ () -> String in
            XCTFail("debug should not be called")
            return "debug"
            }())
        #endif
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
        LoggingSystem.bootstrapInternal({ MultiplexLogHandler([logging1.make(label: $0), logging2.make(label: $0)]) })

        var logger = Logger(label: "test")
        logger.logLevel = .warning
        logger.info("hello world?")
        logger[metadataKey: "foo"] = .string("bar")
        logger.warning("hello world!")
        logging1.history.assertNotExist(level: .info, message: "hello world?")
        logging2.history.assertNotExist(level: .info, message: "hello world?")
        logging1.history.assertExist(level: .warning, message: "hello world!", metadata: ["foo": "bar"])
        logging2.history.assertExist(level: .warning, message: "hello world!", metadata: ["foo": "bar"])
    }

    enum TestError: Error {
        case boom
    }

    // Example of custom "box" which may be used to implement "render at most once" semantics
    // Not thread-safe, thus should not be shared across threads.
    internal class LazyMetadataBox: CustomStringConvertible {
        private var makeValue: (() -> String)?
        private var _value: String? = nil

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

    #if swift(>=4.1.50)
    #if compiler(>=5.0)
    private func dontEvaluateThisString(file: StaticString = #file, line: UInt = #line) -> Logger.Message {
        XCTFail("should not have been evaluated", file: file, line: line)
        return "should not have been evaluated"
    }
    #else
    private func dontEvaluateThisString(file: StaticString = #file, line: UInt = #line) -> String {
        XCTFail("should not have been evaluated", file: file, line: line)
        return "should not have been evaluated"
    }
    #endif
    #else
    private func dontEvaluateThisString(file: StaticString = #file, line: UInt = #line) -> String {
        XCTFail("should not have been evaluated", file: file, line: line)
        return "should not have been evaluated"
    }
    #endif

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
        logger[metadataKey: "bar"] = .string("baz")
        logger[metadataKey: "baz"] = .string("qux")
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

        let someInt = 42
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
        let multi = MultiplexLogHandler([StdoutLogHandler(label: "x"), StdoutLogHandler(label: "y")])
        LoggingSystem.bootstrapInternal { _ in
            print("new multi")
            return multi
        }
        var logger1: Logger = {
            var logger = Logger(label: "foo")
            logger.logLevel = .debug
            logger[metadataKey: "only-on"] = .string("first")
            return logger
        }()
        XCTAssertEqual(.debug, logger1.logLevel)
        var logger2 = logger1
        logger2.logLevel = .error
        logger2[metadataKey: "only-on"] = .string("second")
        XCTAssertEqual(.error, logger2.logLevel)
        XCTAssertEqual(.debug, logger1.logLevel)
        XCTAssertEqual(.string("first"), logger1[metadataKey: "only-on"])
        XCTAssertEqual(.string("second"), logger2[metadataKey: "only-on"])
        logger1.error("hey")
    }

    func testLoggerWithGlobalOverride() {
        struct LogHandlerWithGlobalLogLevelOverride: LogHandler {
            // the static properties hold the globally overridden log level (if overridden)
            private static let overrideLock = Lock()
            private static var overrideLogLevel: Logger.Level? = nil

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
                        return LogHandlerWithGlobalLogLevelOverride.overrideLogLevel
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
            return LogHandlerWithGlobalLogLevelOverride(recorder: logRecorder)
        }

        var logger1 = Logger(label: "logger-\(#file):\(#line)")
        var logger2 = logger1
        logger1.logLevel = .warning
        logger1[metadataKey: "only-on"] = .string("first")
        logger2.logLevel = .error
        logger2[metadataKey: "only-on"] = .string("second")
        XCTAssertEqual(.error, logger2.logLevel)
        XCTAssertEqual(.warning, logger1.logLevel)
        XCTAssertEqual(Logger.MetadataValue.string("first"), logger1[metadataKey: "only-on"])
        XCTAssertEqual(Logger.MetadataValue.string("second"), logger2[metadataKey: "only-on"])

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
}
