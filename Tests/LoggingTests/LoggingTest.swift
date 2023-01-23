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
#elseif os(Windows)
import WinSDK
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

    func testMultiplexLogHandlerWithVariousLogLevels() throws {
        let logging1 = TestLogging()
        let logging2 = TestLogging()

        var logger1 = logging1.make(label: "1")
        logger1.logLevel = .info

        var logger2 = logging2.make(label: "2")
        logger2.logLevel = .debug

        LoggingSystem.bootstrapInternal { _ in
            MultiplexLogHandler([logger1, logger2])
        }

        let multiplexLogger = Logger(label: "test")
        multiplexLogger.trace("trace")
        multiplexLogger.debug("debug")
        multiplexLogger.info("info")
        multiplexLogger.warning("warning")

        logging1.history.assertNotExist(level: .trace, message: "trace")
        logging1.history.assertNotExist(level: .debug, message: "debug")
        logging1.history.assertExist(level: .info, message: "info")
        logging1.history.assertExist(level: .warning, message: "warning")

        logging2.history.assertNotExist(level: .trace, message: "trace")
        logging2.history.assertExist(level: .debug, message: "debug")
        logging2.history.assertExist(level: .info, message: "info")
        logging2.history.assertExist(level: .warning, message: "warning")
    }

    func testMultiplexLogHandlerNeedNotMaterializeValuesMultipleTimes() throws {
        let logging1 = TestLogging()
        let logging2 = TestLogging()

        var logger1 = logging1.make(label: "1")
        logger1.logLevel = .info

        var logger2 = logging2.make(label: "2")
        logger2.logLevel = .info

        LoggingSystem.bootstrapInternal { _ in
            MultiplexLogHandler([logger1, logger2])
        }

        var messageMaterializations: Int = 0
        var metadataMaterializations: Int = 0

        let multiplexLogger = Logger(label: "test")
        multiplexLogger.info(
            { () -> Logger.Message in
                messageMaterializations += 1
                return "info"
            }(),
            metadata: { () ->
                Logger.Metadata in metadataMaterializations += 1
                return [:]
            }()
        )

        logging1.history.assertExist(level: .info, message: "info")
        logging2.history.assertExist(level: .info, message: "info")

        XCTAssertEqual(messageMaterializations, 1)
        XCTAssertEqual(metadataMaterializations, 1)
    }

    func testMultiplexLogHandlerMetadata_settingMetadataThroughToUnderlyingHandlers() {
        let logging1 = TestLogging()
        let logging2 = TestLogging()

        var logger1 = logging1.make(label: "1")
        logger1.metadata["one"] = "111"
        logger1.metadata["in"] = "in-1"
        var logger2 = logging2.make(label: "2")
        logger2.metadata["two"] = "222"
        logger2.metadata["in"] = "in-2"

        LoggingSystem.bootstrapInternal { _ in
            MultiplexLogHandler([logger1, logger2])
        }

        var multiplexLogger = Logger(label: "test")

        // each logs its own metadata
        multiplexLogger.info("info")
        logging1.history.assertExist(level: .info, message: "info", metadata: [
            "one": "111",
            "in": "in-1",
        ])
        logging2.history.assertExist(level: .info, message: "info", metadata: [
            "two": "222",
            "in": "in-2",
        ])

        // if modified, change applies to both underlying handlers
        multiplexLogger[metadataKey: "new"] = "new"
        multiplexLogger.info("info")
        logging1.history.assertExist(level: .info, message: "info", metadata: [
            "one": "111",
            "in": "in-1",
            "new": "new",
        ])
        logging2.history.assertExist(level: .info, message: "info", metadata: [
            "two": "222",
            "in": "in-2",
            "new": "new",
        ])

        // overriding an existing value works the same way as adding a new one
        multiplexLogger[metadataKey: "in"] = "multi"
        multiplexLogger.info("info")
        logging1.history.assertExist(level: .info, message: "info", metadata: [
            "one": "111",
            "in": "multi",
            "new": "new",
        ])
        logging2.history.assertExist(level: .info, message: "info", metadata: [
            "two": "222",
            "in": "multi",
            "new": "new",
        ])
    }

    func testMultiplexLogHandlerMetadata_readingHandlerMetadata() {
        let logging1 = TestLogging()
        let logging2 = TestLogging()

        var logger1 = logging1.make(label: "1")
        logger1.metadata["one"] = "111"
        logger1.metadata["in"] = "in-1"
        var logger2 = logging2.make(label: "2")
        logger2.metadata["two"] = "222"
        logger2.metadata["in"] = "in-2"

        LoggingSystem.bootstrapInternal { _ in
            MultiplexLogHandler([logger1, logger2])
        }

        let multiplexLogger = Logger(label: "test")

        XCTAssertEqual(multiplexLogger.handler.metadata, [
            "one": "111",
            "two": "222",
            "in": "in-2",
        ])
    }

    func testMultiplexMetadataProviderSet() {
        let logging1 = TestLogging()
        let logging2 = TestLogging()

        var handler1 = logging1.make(label: "1")
        handler1.metadata["one"] = "111"
        handler1.metadata["in"] = "in-1"
        handler1.metadataProvider = .constant([
            "provider-1": "provided-111",
            "provider-overlap": "provided-111",
        ])
        var handler2 = logging2.make(label: "2")
        handler2.metadata["two"] = "222"
        handler2.metadata["in"] = "in-2"
        handler2.metadataProvider = .constant([
            "provider-2": "provided-222",
            "provider-overlap": "provided-222",
        ])

        LoggingSystem.bootstrapInternal { _ in
            MultiplexLogHandler([handler1, handler2])
        }

        let multiplexLogger = Logger(label: "test")

        XCTAssertEqual(multiplexLogger.handler.metadata, [
            "one": "111",
            "two": "222",
            "in": "in-2",
            "provider-1": "provided-111",
            "provider-2": "provided-222",
            "provider-overlap": "provided-222",
        ])
        XCTAssertEqual(multiplexLogger.handler.metadataProvider?.get(), [
            "provider-1": "provided-111",
            "provider-2": "provided-222",
            "provider-overlap": "provided-222",
        ])
    }

    func testMultiplexMetadataProviderExtract() {
        let logging1 = TestLogging()
        let logging2 = TestLogging()

        var handler1 = logging1.make(label: "1")
        handler1.metadataProvider = .constant([
            "provider-1": "provided-111",
            "provider-overlap": "provided-111",
        ])
        var handler2 = logging2.make(label: "2")
        handler2.metadata["two"] = "222"
        handler2.metadata["in"] = "in-2"
        handler2.metadataProvider = .constant([
            "provider-2": "provided-222",
            "provider-overlap": "provided-222",
        ])

        LoggingSystem.bootstrapInternal({ _, metadataProvider in
            MultiplexLogHandler(
                [handler1, handler2],
                metadataProvider: metadataProvider
            )
        }, metadataProvider: .constant([
            "provider-overlap": "provided-outer",
        ]))

        let multiplexLogger = Logger(label: "test")

        let provider = multiplexLogger.metadataProvider!

        XCTAssertEqual(provider.get(), [
            "provider-1": "provided-111",
            "provider-2": "provided-222",
            "provider-overlap": "provided-outer",
        ])
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
    internal final class LazyMetadataBox: CustomStringConvertible {
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
            func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {}

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

    func testAllLogLevelByFunctionRefWithSource() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)

        var logger = Logger(label: "\(#function)")
        logger.logLevel = .trace

        let trace = logger.trace(_:metadata:source:file:function:line:)
        let debug = logger.debug(_:metadata:source:file:function:line:)
        let info = logger.info(_:metadata:source:file:function:line:)
        let notice = logger.notice(_:metadata:source:file:function:line:)
        let warning = logger.warning(_:metadata:source:file:function:line:)
        let error = logger.error(_:metadata:source:file:function:line:)
        let critical = logger.critical(_:metadata:source:file:function:line:)

        trace("yes: trace", [:], "foo", #file, #function, #line)
        debug("yes: debug", [:], "foo", #file, #function, #line)
        info("yes: info", [:], "foo", #file, #function, #line)
        notice("yes: notice", [:], "foo", #file, #function, #line)
        warning("yes: warning", [:], "foo", #file, #function, #line)
        error("yes: error", [:], "foo", #file, #function, #line)
        critical("yes: critical", [:], "foo", #file, #function, #line)

        testLogging.history.assertExist(level: .trace, message: "yes: trace", source: "foo")
        testLogging.history.assertExist(level: .debug, message: "yes: debug", source: "foo")
        testLogging.history.assertExist(level: .info, message: "yes: info", source: "foo")
        testLogging.history.assertExist(level: .notice, message: "yes: notice", source: "foo")
        testLogging.history.assertExist(level: .warning, message: "yes: warning", source: "foo")
        testLogging.history.assertExist(level: .error, message: "yes: error", source: "foo")
        testLogging.history.assertExist(level: .critical, message: "yes: critical", source: "foo")
    }

    func testAllLogLevelByFunctionRefWithoutSource() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)

        var logger = Logger(label: "\(#function)")
        logger.logLevel = .trace

        let trace = logger.trace(_:metadata:file:function:line:)
        let debug = logger.debug(_:metadata:file:function:line:)
        let info = logger.info(_:metadata:file:function:line:)
        let notice = logger.notice(_:metadata:file:function:line:)
        let warning = logger.warning(_:metadata:file:function:line:)
        let error = logger.error(_:metadata:file:function:line:)
        let critical = logger.critical(_:metadata:file:function:line:)

        #if compiler(>=5.3)
        trace("yes: trace", [:], #fileID, #function, #line)
        debug("yes: debug", [:], #fileID, #function, #line)
        info("yes: info", [:], #fileID, #function, #line)
        notice("yes: notice", [:], #fileID, #function, #line)
        warning("yes: warning", [:], #fileID, #function, #line)
        error("yes: error", [:], #fileID, #function, #line)
        critical("yes: critical", [:], #fileID, #function, #line)
        #else
        trace("yes: trace", [:], #file, #function, #line)
        debug("yes: debug", [:], #file, #function, #line)
        info("yes: info", [:], #file, #function, #line)
        notice("yes: notice", [:], #file, #function, #line)
        warning("yes: warning", [:], #file, #function, #line)
        error("yes: error", [:], #file, #function, #line)
        critical("yes: critical", [:], #file, #function, #line)
        #endif

        testLogging.history.assertExist(level: .trace, message: "yes: trace")
        testLogging.history.assertExist(level: .debug, message: "yes: debug")
        testLogging.history.assertExist(level: .info, message: "yes: info")
        testLogging.history.assertExist(level: .notice, message: "yes: notice")
        testLogging.history.assertExist(level: .warning, message: "yes: warning")
        testLogging.history.assertExist(level: .error, message: "yes: error")
        testLogging.history.assertExist(level: .critical, message: "yes: critical")
    }

    func testLogsEmittedFromSubdirectoryGetCorrectModuleInNewerSwifts() {
        let testLogging = TestLogging()
        LoggingSystem.bootstrapInternal(testLogging.make)

        var logger = Logger(label: "\(#function)")
        logger.logLevel = .trace

        emitLogMessage("hello", to: logger)

        #if compiler(>=5.3)
        let moduleName = "LoggingTests" // the actual name
        #else
        let moduleName = "SubDirectoryOfLoggingTests" // the last path component of `#file` showing the failure mode
        #endif

        testLogging.history.assertExist(level: .trace, message: "hello", source: moduleName)
        testLogging.history.assertExist(level: .debug, message: "hello", source: moduleName)
        testLogging.history.assertExist(level: .info, message: "hello", source: moduleName)
        testLogging.history.assertExist(level: .notice, message: "hello", source: moduleName)
        testLogging.history.assertExist(level: .warning, message: "hello", source: moduleName)
        testLogging.history.assertExist(level: .error, message: "hello", source: moduleName)
        testLogging.history.assertExist(level: .critical, message: "hello", source: moduleName)
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

    func testMultiplexMetadataProviderMergesInSpecifiedOrder() {
        let logging = TestLogging()

        let providerA = Logger.MetadataProvider { ["provider": "a", "a": "foo"] }
        let providerB = Logger.MetadataProvider { ["provider": "b", "b": "bar"] }
        let logger = Logger(label: #function,
                            factory: { label in
                                logging.makeWithMetadataProvider(label: label, metadataProvider: .multiplex([providerA, providerB]))
                            })

        logger.log(level: .info, "test", metadata: ["one-off": "42"])

        logging.history.assertExist(level: .info,
                                    message: "test",
                                    metadata: ["provider": "b", "a": "foo", "b": "bar", "one-off": "42"])
    }

    func testLoggerWithoutFactoryOverrideDefaultsToUsingLoggingSystemMetadataProvider() {
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal({ label, metadataProvider in
            logging.makeWithMetadataProvider(label: label, metadataProvider: metadataProvider)
        }, metadataProvider: .init { ["provider": "42"] })

        let logger = Logger(label: #function)

        logger.log(level: .info, "test", metadata: ["one-off": "42"])

        logging.history.assertExist(level: .info,
                                    message: "test",
                                    metadata: ["provider": "42", "one-off": "42"])
    }

    func testLoggerWithPredefinedLibraryMetadataProvider() {
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal(
            logging.makeWithMetadataProvider,
            metadataProvider: .exampleMetadataProvider
        )

        let logger = Logger(label: #function)

        logger.log(level: .info, "test", metadata: ["one-off": "42"])

        logging.history.assertExist(level: .info,
                                    message: "test",
                                    metadata: ["example": "example-value", "one-off": "42"])
    }

    func testLoggerWithFactoryOverrideDefaultsToUsingLoggingSystemMetadataProvider() {
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal(logging.makeWithMetadataProvider, metadataProvider: .init { ["provider": "42"] })

        let logger = Logger(label: #function, factory: { label in
            logging.makeWithMetadataProvider(label: label, metadataProvider: LoggingSystem.metadataProvider)
        })

        logger.log(level: .info, "test", metadata: ["one-off": "42"])

        logging.history.assertExist(level: .info,
                                    message: "test",
                                    metadata: ["provider": "42", "one-off": "42"])
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
                     source: String, file: String, function: String, line: UInt) {
                self.recorder.record(level: level, metadata: metadata, message: message, source: source)
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
        LoggingSystem.bootstrapInternal { label in
            StreamLogHandler(label: label, stream: interceptStream)
        }
        let source = "testSource"
        let log = Logger(label: label)

        let testString = "my message is better than yours"
        log.critical("\(testString)", source: source)

        let pattern = "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+|-)\\d{4}\\s\(Logger.Level.critical)\\s\(label)\\s:\\s\\[\(source)\\]\\s\(testString)$"

        let messageSucceeded = interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines).range(of: pattern, options: .regularExpression) != nil

        XCTAssertTrue(messageSucceeded)
        XCTAssertEqual(interceptStream.strings.count, 1)
    }

    func testStreamLogHandlerOutputFormatWithMetaData() {
        let interceptStream = InterceptStream()
        let label = "testLabel"
        LoggingSystem.bootstrapInternal { label in
            StreamLogHandler(label: label, stream: interceptStream)
        }
        let source = "testSource"
        let log = Logger(label: label)

        let testString = "my message is better than yours"
        log.critical("\(testString)", metadata: ["test": "test"], source: source)

        let pattern = "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+|-)\\d{4}\\s\(Logger.Level.critical)\\s\(label)\\s:\\stest=test\\s\\[\(source)\\]\\s\(testString)$"

        let messageSucceeded = interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines).range(of: pattern, options: .regularExpression) != nil

        XCTAssertTrue(messageSucceeded)
        XCTAssertEqual(interceptStream.strings.count, 1)
    }

    func testStreamLogHandlerOutputFormatWithOrderedMetadata() {
        let interceptStream = InterceptStream()
        let label = "testLabel"
        LoggingSystem.bootstrapInternal { label in
            StreamLogHandler(label: label, stream: interceptStream)
        }
        let log = Logger(label: label)

        let testString = "my message is better than yours"
        log.critical("\(testString)", metadata: ["a": "a0", "b": "b0"])
        log.critical("\(testString)", metadata: ["b": "b1", "a": "a1"])

        XCTAssertEqual(interceptStream.strings.count, 2)
        guard interceptStream.strings.count == 2 else {
            XCTFail("Intercepted \(interceptStream.strings.count) logs, expected 2")
            return
        }

        XCTAssert(interceptStream.strings[0].contains("a=a0 b=b0"), "LINES: \(interceptStream.strings[0])")
        XCTAssert(interceptStream.strings[1].contains("a=a1 b=b1"), "LINES: \(interceptStream.strings[1])")
    }

    func testStreamLogHandlerWritesIncludeMetadataProviderMetadata() {
        let interceptStream = InterceptStream()
        LoggingSystem.bootstrapInternal({ _, metadataProvider in
            StreamLogHandler(label: "test", stream: interceptStream, metadataProvider: metadataProvider)
        }, metadataProvider: .exampleMetadataProvider)
        let log = Logger(label: "test")

        let testString = "my message is better than yours"
        log.critical("\(testString)")

        let messageSucceeded = interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(testString)

        XCTAssertTrue(messageSucceeded ?? false)
        XCTAssertEqual(interceptStream.strings.count, 1)
        let message = interceptStream.strings.first!
        XCTAssertTrue(message.contains("example=example-value"), "message must contain metadata, was: \(message)")
    }

    func testStdioOutputStreamWrite() {
        self.withWriteReadFDsAndReadBuffer { writeFD, readFD, readBuffer in
            let logStream = StdioOutputStream(file: writeFD, flushMode: .always)
            LoggingSystem.bootstrapInternal { StreamLogHandler(label: $0, stream: logStream) }
            let log = Logger(label: "test")
            let testString = "hello\u{0} world"
            log.critical("\(testString)")

            let size = read(readFD, readBuffer, 256)

            let output = String(decoding: UnsafeRawBufferPointer(start: UnsafeRawPointer(readBuffer), count: numericCast(size)), as: UTF8.self)
            let messageSucceeded = output.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(testString)
            XCTAssertTrue(messageSucceeded)
        }
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

    func withWriteReadFDsAndReadBuffer(_ body: (CFilePointer, CInt, UnsafeMutablePointer<Int8>) -> Void) {
        var fds: [Int32] = [-1, -1]
        #if os(Windows)
        fds.withUnsafeMutableBufferPointer {
            let err = _pipe($0.baseAddress, 256, _O_BINARY)
            XCTAssertEqual(err, 0, "_pipe failed \(err)")
        }
        #else
        fds.withUnsafeMutableBufferPointer { ptr in
            let err = pipe(ptr.baseAddress!)
            XCTAssertEqual(err, 0, "pipe failed \(err)")
        }
        #endif

        let writeFD = fdopen(fds[1], "w")
        let writeBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        defer {
            writeBuffer.deinitialize(count: 256)
            writeBuffer.deallocate()
        }

        var err = setvbuf(writeFD, writeBuffer, _IOFBF, 256)
        XCTAssertEqual(err, 0, "setvbuf failed \(err)")

        let readFD = fds[0]
        #if os(Windows)
        let hPipe: HANDLE = HANDLE(bitPattern: _get_osfhandle(readFD))!
        XCTAssertFalse(hPipe == INVALID_HANDLE_VALUE)

        var dwMode: DWORD = DWORD(PIPE_NOWAIT)
        let bSucceeded = SetNamedPipeHandleState(hPipe, &dwMode, nil, nil)
        XCTAssertTrue(bSucceeded)
        #else
        err = fcntl(readFD, F_SETFL, fcntl(readFD, F_GETFL) | O_NONBLOCK)
        XCTAssertEqual(err, 0, "fcntl failed \(err)")
        #endif

        let readBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        defer {
            readBuffer.deinitialize(count: 256)
            readBuffer.deallocate()
        }

        // the actual test
        body(writeFD!, readFD, readBuffer)

        fds.forEach { close($0) }
    }

    func testOverloadingError() {
        struct Dummy: Error, LocalizedError {
            var errorDescription: String? {
                return "errorDescription"
            }
        }
        // bootstrap with our test logging impl
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal(logging.make)

        var logger = Logger(label: "test")
        logger.logLevel = .error
        logger.error(error: Dummy())

        logging.history.assertExist(level: .error, message: "errorDescription")
    }

    func testCompileInitializeStandardStreamLogHandlersWithMetadataProviders() {
        // avoid "unreachable code" warnings
        let dontExecute = Int.random(in: 100 ... 200) == 1
        guard dontExecute else {
            return
        }

        // default usage
        LoggingSystem.bootstrap(StreamLogHandler.standardOutput)
        LoggingSystem.bootstrap(StreamLogHandler.standardError)

        // with metadata handler, explicitly, public api
        LoggingSystem.bootstrap({ label, metadataProvider in
            StreamLogHandler.standardOutput(label: label, metadataProvider: metadataProvider)
        }, metadataProvider: .exampleMetadataProvider)
        LoggingSystem.bootstrap({ label, metadataProvider in
            StreamLogHandler.standardError(label: label, metadataProvider: metadataProvider)
        }, metadataProvider: .exampleMetadataProvider)

        // with metadata handler, still pretty
        LoggingSystem.bootstrap(StreamLogHandler.standardOutput, metadataProvider: .exampleMetadataProvider)
        LoggingSystem.bootstrap(StreamLogHandler.standardError, metadataProvider: .exampleMetadataProvider)
    }
}

extension Logger {
    #if compiler(>=5.3)
    public func error(error: Error,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.error("\(error.localizedDescription)", metadata: metadata(), file: file, function: function, line: line)
    }

    #else
    public func error(error: Error,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.error("\(error.localizedDescription)", metadata: metadata(), file: file, function: function, line: line)
    }
    #endif
}

extension Logger.MetadataProvider {
    static var exampleMetadataProvider: Self {
        .init { ["example": .string("example-value")] }
    }

    static func constant(_ metadata: Logger.Metadata) -> Self {
        .init { metadata }
    }
}

// Sendable

#if compiler(>=5.6)
// used to test logging metadata which requires Sendable conformance
// @unchecked Sendable since manages it own state
extension LoggingTest.LazyMetadataBox: @unchecked Sendable {}

// used to test logging stream which requires Sendable conformance
// @unchecked Sendable since manages it own state
extension LoggingTest.InterceptStream: @unchecked Sendable {}
#endif
