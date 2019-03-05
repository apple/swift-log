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
        logger.log(level: .debug, {
            XCTFail("trace should not be called")
            return "trace"
        }())
        logger.debug({
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
        LoggingSystem.bootstrapInternal({ MultiplexLogHandler([logging1.make(label: $0), logging2.make(label: $0)]) })

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

    func testStringConvertibleMetadata() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)
        var logger = Logger(label: "\(#function)")

        logger[metadataKey: "foo"] = .stringConvertible("raw-string")
        let lazyBox = LazyMetadataBox({ "rendered-at-first-use" })
        logger[metadataKey: "lazy"] = .stringConvertible(lazyBox)
        logger.info("hello world!")
        testLogging.history.assertExist(level: .info,
                                        message: "hello world!",
                                        metadata: ["foo": .stringConvertible("raw-string"),
                                                   "lazy": .stringConvertible(LazyMetadataBox({ "rendered-at-first-use" }))])
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
            func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: StaticString, function: StaticString, line: UInt) {}

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

    func testAllLogLevelsExceptEmergencyCanBeBlocked() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)

        var logger = Logger(label: "\(#function)")
        logger.logLevel = .emergency

        logger.debug("no")
        logger.info("no")
        logger.notice("no")
        logger.warning("no")
        logger.error("no")
        logger.critical("no")
        logger.alert("no")
        logger.emergency("yes")

        testLogging.history.assertNotExist(level: .debug, message: "no")
        testLogging.history.assertNotExist(level: .info, message: "no")
        testLogging.history.assertNotExist(level: .notice, message: "no")
        testLogging.history.assertNotExist(level: .warning, message: "no")
        testLogging.history.assertNotExist(level: .error, message: "no")
        testLogging.history.assertNotExist(level: .critical, message: "no")
        testLogging.history.assertNotExist(level: .alert, message: "no")
        testLogging.history.assertExist(level: .emergency, message: "yes")
    }

    func testAllLogLevelsWork() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)

        var logger = Logger(label: "\(#function)")
        logger.logLevel = .debug

        logger.debug("yes")
        logger.info("yes")
        logger.notice("yes")
        logger.warning("yes")
        logger.error("yes")
        logger.critical("yes")
        logger.alert("yes")
        logger.emergency("yes")

        testLogging.history.assertExist(level: .debug, message: "yes")
        testLogging.history.assertExist(level: .info, message: "yes")
        testLogging.history.assertExist(level: .notice, message: "yes")
        testLogging.history.assertExist(level: .warning, message: "yes")
        testLogging.history.assertExist(level: .error, message: "yes")
        testLogging.history.assertExist(level: .critical, message: "yes")
        testLogging.history.assertExist(level: .alert, message: "yes")
        testLogging.history.assertExist(level: .emergency, message: "yes")
    }

    func testLogMessageWithStringInterpolation() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)

        var logger = Logger(label: "\(#function)")
        logger.logLevel = .debug

        let someInt = Int.random(in: 23..<42)
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
}
