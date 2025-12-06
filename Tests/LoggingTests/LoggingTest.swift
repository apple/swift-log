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

import Foundation
import Testing

@testable import Logging

#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import WinSDK
#elseif canImport(Android)
import Android
#else
import Glibc
#endif

extension LogHandler {
    fileprivate func with(logLevel: Logger.Level) -> any LogHandler {
        var result = self
        result.logLevel = logLevel
        return result
    }

    fileprivate func withMetadata(_ key: String, _ value: Logger.MetadataValue) -> any LogHandler {
        var result = self
        result.metadata[key] = value
        return result
    }
}

struct LoggingTest {
    @Test func autoclosure() throws {
        // create test logging impl, do not bootstrap global LoggingSystem
        let logging = TestLogging()

        var logger = Logger(
            label: "test",
            factory: {
                logging.make(label: $0)
            }
        )
        logger.logLevel = .info
        logger.log(
            level: .debug,
            {
                Issue.record("debug should not be called")
                return "debug"
            }()
        )
        logger.trace(
            {
                Issue.record("trace should not be called")
                return "trace"
            }()
        )
        logger.debug(
            {
                Issue.record("debug should not be called")
                return "debug"
            }()
        )
        logger.info(
            {
                "info"
            }()
        )
        logger.warning(
            {
                "warning"
            }()
        )
        logger.error(
            {
                "error"
            }()
        )
        #expect(3 == logging.history.entries.count, "expected number of entries to match")
        logging.history.assertNotExist(level: .debug, message: "trace")
        logging.history.assertNotExist(level: .debug, message: "debug")
        logging.history.assertExist(level: .info, message: "info")
        logging.history.assertExist(level: .warning, message: "warning")
        logging.history.assertExist(level: .error, message: "error")
    }

    @Test func multiplex() throws {
        // create test logging impl, do not bootstrap global LoggingSystem
        let logging1 = TestLogging()
        let logging2 = TestLogging()

        var logger = Logger(
            label: "test",
            factory: {
                MultiplexLogHandler([logging1.make(label: $0), logging2.make(label: $0)])
            }
        )
        logger.logLevel = .warning
        logger.info("hello world?")
        logger[metadataKey: "foo"] = "bar"
        logger.warning("hello world!")
        logging1.history.assertNotExist(level: .info, message: "hello world?")
        logging2.history.assertNotExist(level: .info, message: "hello world?")
        logging1.history.assertExist(level: .warning, message: "hello world!", metadata: ["foo": "bar"])
        logging2.history.assertExist(level: .warning, message: "hello world!", metadata: ["foo": "bar"])
    }

    @Test func multiplexLogHandlerWithVariousLogLevels() throws {
        let logging1 = TestLogging()
        let logging2 = TestLogging()

        let logger1 = logging1.make(label: "1").with(logLevel: .info)
        let logger2 = logging2.make(label: "2").with(logLevel: .debug)

        let multiplexLogger = Logger(
            label: "test",
            factory: { _ in
                MultiplexLogHandler([logger1, logger2])
            }
        )
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

    @Test func multiplexLogHandlerNeedNotMaterializeValuesMultipleTimes() throws {
        let logging1 = TestLogging()
        let logging2 = TestLogging()

        let logger1 = logging1.make(label: "1").with(logLevel: .info)
        let logger2 = logging2.make(label: "2").with(logLevel: .info)

        var messageMaterializations: Int = 0
        var metadataMaterializations: Int = 0

        let multiplexLogger = Logger(
            label: "test",
            factory: { _ in
                MultiplexLogHandler([logger1, logger2])
            }
        )
        multiplexLogger.info(
            { () -> Logger.Message in
                messageMaterializations += 1
                return "info"
            }(),
            metadata: { () -> Logger.Metadata in
                metadataMaterializations += 1
                return [:]
            }()
        )

        logging1.history.assertExist(level: .info, message: "info")
        logging2.history.assertExist(level: .info, message: "info")

        #expect(messageMaterializations == 1)
        #expect(metadataMaterializations == 1)
    }

    @Test func multiplexLogHandlerMetadata_settingMetadataThroughToUnderlyingHandlers() {
        let logging1 = TestLogging()
        let logging2 = TestLogging()

        let logger1 = logging1.make(label: "1")
            .withMetadata("one", "111")
            .withMetadata("in", "in-1")
        let logger2 = logging2.make(label: "2")
            .withMetadata("two", "222")
            .withMetadata("in", "in-2")

        var multiplexLogger = Logger(
            label: "test",
            factory: { _ in
                MultiplexLogHandler([logger1, logger2])
            }
        )

        // each logs its own metadata
        multiplexLogger.info("info")
        logging1.history.assertExist(
            level: .info,
            message: "info",
            metadata: [
                "one": "111",
                "in": "in-1",
            ]
        )
        logging2.history.assertExist(
            level: .info,
            message: "info",
            metadata: [
                "two": "222",
                "in": "in-2",
            ]
        )

        // if modified, change applies to both underlying handlers
        multiplexLogger[metadataKey: "new"] = "new"
        multiplexLogger.info("info")
        logging1.history.assertExist(
            level: .info,
            message: "info",
            metadata: [
                "one": "111",
                "in": "in-1",
                "new": "new",
            ]
        )
        logging2.history.assertExist(
            level: .info,
            message: "info",
            metadata: [
                "two": "222",
                "in": "in-2",
                "new": "new",
            ]
        )

        // overriding an existing value works the same way as adding a new one
        multiplexLogger[metadataKey: "in"] = "multi"
        multiplexLogger.info("info")
        logging1.history.assertExist(
            level: .info,
            message: "info",
            metadata: [
                "one": "111",
                "in": "multi",
                "new": "new",
            ]
        )
        logging2.history.assertExist(
            level: .info,
            message: "info",
            metadata: [
                "two": "222",
                "in": "multi",
                "new": "new",
            ]
        )
    }

    @Test func multiplexLogHandlerMetadata_readingHandlerMetadata() {
        let logging1 = TestLogging()
        let logging2 = TestLogging()

        let logger1 = logging1.make(label: "1")
            .withMetadata("one", "111")
            .withMetadata("in", "in-1")
        let logger2 = logging2.make(label: "2")
            .withMetadata("two", "222")
            .withMetadata("in", "in-2")

        let multiplexLogger = Logger(
            label: "test",
            factory: { _ in
                MultiplexLogHandler([logger1, logger2])
            }
        )

        #expect(
            multiplexLogger.handler.metadata == [
                "one": "111",
                "two": "222",
                "in": "in-2",
            ]
        )
    }

    @Test func multiplexMetadataProviderSet() {
        let logging1 = TestLogging()
        let logging2 = TestLogging()

        let handler1 = {
            var handler1 = logging1.make(label: "1")
            handler1.metadata["one"] = "111"
            handler1.metadata["in"] = "in-1"
            handler1.metadataProvider = .constant([
                "provider-1": "provided-111",
                "provider-overlap": "provided-111",
            ])
            return handler1
        }()
        let handler2 = {
            var handler2 = logging2.make(label: "2")
            handler2.metadata["two"] = "222"
            handler2.metadata["in"] = "in-2"
            handler2.metadataProvider = .constant([
                "provider-2": "provided-222",
                "provider-overlap": "provided-222",
            ])
            return handler2
        }()

        let multiplexLogger = Logger(
            label: "test",
            factory: { _ in
                MultiplexLogHandler([handler1, handler2])
            }
        )

        #expect(
            multiplexLogger.handler.metadata == [
                "one": "111",
                "two": "222",
                "in": "in-2",
                "provider-1": "provided-111",
                "provider-2": "provided-222",
                "provider-overlap": "provided-222",
            ]
        )
        #expect(
            multiplexLogger.handler.metadataProvider?.get() == [
                "provider-1": "provided-111",
                "provider-2": "provided-222",
                "provider-overlap": "provided-222",
            ]
        )
    }

    @Test func multiplexMetadataProviderExtract() {
        let logging1 = TestLogging()
        let logging2 = TestLogging()

        let handler1 = {
            var handler1 = logging1.make(label: "1")
            handler1.metadataProvider = .constant([
                "provider-1": "provided-111",
                "provider-overlap": "provided-111",
            ])
            return handler1
        }()
        let handler2 = {
            var handler2 = logging2.make(label: "2")
            handler2.metadata["two"] = "222"
            handler2.metadata["in"] = "in-2"
            handler2.metadataProvider = .constant([
                "provider-2": "provided-222",
                "provider-overlap": "provided-222",
            ])
            return handler2
        }()

        let multiplexLogger = Logger(
            label: "test",
            factory: { _ in
                MultiplexLogHandler(
                    [handler1, handler2],
                    metadataProvider: .constant([
                        "provider-overlap": "provided-outer"
                    ])
                )
            }
        )

        let provider = multiplexLogger.metadataProvider!

        #expect(
            provider.get() == [
                "provider-1": "provided-111",
                "provider-2": "provided-222",
                "provider-overlap": "provided-outer",
            ]
        )
    }

    enum TestError: Error {
        case boom
    }

    @Test func dictionaryMetadata() {
        let testLogging = TestLogging()

        var logger = Logger(
            label: "\(#function)",
            factory: {
                testLogging.make(label: $0)
            }
        )
        logger[metadataKey: "foo"] = ["bar": "buz"]
        logger[metadataKey: "empty-dict"] = [:]
        logger[metadataKey: "nested-dict"] = ["l1key": ["l2key": ["l3key": "l3value"]]]
        logger.info("hello world!")
        testLogging.history.assertExist(
            level: .info,
            message: "hello world!",
            metadata: [
                "foo": ["bar": "buz"],
                "empty-dict": [:],
                "nested-dict": ["l1key": ["l2key": ["l3key": "l3value"]]],
            ]
        )
    }

    @Test func listMetadata() {
        let testLogging = TestLogging()

        var logger = Logger(
            label: "\(#function)",
            factory: {
                testLogging.make(label: $0)
            }
        )
        logger[metadataKey: "foo"] = ["bar", "buz"]
        logger[metadataKey: "empty-list"] = []
        logger[metadataKey: "nested-list"] = ["l1str", ["l2str1", "l2str2"]]
        logger.info("hello world!")
        testLogging.history.assertExist(
            level: .info,
            message: "hello world!",
            metadata: [
                "foo": ["bar", "buz"],
                "empty-list": [],
                "nested-list": ["l1str", ["l2str1", "l2str2"]],
            ]
        )
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
            "\(self.value)"
        }
    }

    @Test func stringConvertibleMetadata() {
        let testLogging = TestLogging()
        var logger = Logger(
            label: "\(#function)",
            factory: {
                testLogging.make(label: $0)
            }
        )

        logger[metadataKey: "foo"] = .stringConvertible("raw-string")
        let lazyBox = LazyMetadataBox { "rendered-at-first-use" }
        logger[metadataKey: "lazy"] = .stringConvertible(lazyBox)
        logger.info("hello world!")
        testLogging.history.assertExist(
            level: .info,
            message: "hello world!",
            metadata: [
                "foo": .stringConvertible("raw-string"),
                "lazy": .stringConvertible(LazyMetadataBox { "rendered-at-first-use" }),
            ]
        )
    }

    private func dontEvaluateThisString(
        fileID: String = #fileID,
        file: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) -> Logger.Message {
        Issue.record(
            "should not have been evaluated",
            sourceLocation: SourceLocation(fileID: fileID, filePath: "\(file)", line: Int(line), column: Int(column))
        )
        return "should not have been evaluated"
    }

    @Test func autoClosuresAreNotForcedUnlessNeeded() {
        let testLogging = TestLogging()

        var logger = Logger(
            label: "\(#function)",
            factory: {
                testLogging.make(label: $0)
            }
        )
        logger.logLevel = .error

        logger.debug(self.dontEvaluateThisString(), metadata: ["foo": "\(self.dontEvaluateThisString())"])
        logger.debug(self.dontEvaluateThisString())
        logger.info(self.dontEvaluateThisString())
        logger.warning(self.dontEvaluateThisString())
        logger.log(level: .warning, self.dontEvaluateThisString())
    }

    @Test func localMetadata() {
        let testLogging = TestLogging()

        var logger = Logger(
            label: "\(#function)",
            factory: {
                testLogging.make(label: $0)
            }
        )
        logger.info("hello world!", metadata: ["foo": "bar"])
        logger[metadataKey: "bar"] = "baz"
        logger[metadataKey: "baz"] = "qux"
        logger.warning("hello world!")
        logger.error("hello world!", metadata: ["baz": "quc"])
        testLogging.history.assertExist(level: .info, message: "hello world!", metadata: ["foo": "bar"])
        testLogging.history.assertExist(
            level: .warning,
            message: "hello world!",
            metadata: ["bar": "baz", "baz": "qux"]
        )
        testLogging.history.assertExist(level: .error, message: "hello world!", metadata: ["bar": "baz", "baz": "quc"])
    }

    @Test func customFactory() {
        struct CustomHandler: LogHandler {
            func log(
                level: Logger.Level,
                message: Logger.Message,
                metadata: Logger.Metadata?,
                source: String,
                file: String,
                function: String,
                line: UInt
            ) {}

            subscript(metadataKey _: String) -> Logger.Metadata.Value? {
                get { nil }
                set {}
            }

            var metadata: Logger.Metadata {
                get { Logger.Metadata() }
                set {}
            }

            var logLevel: Logger.Level {
                get { .info }
                set {}
            }
        }

        let logger1 = Logger(label: "foo")
        #expect(!(logger1.handler is CustomHandler), "expected non-custom log handler")
        let logger2 = Logger(label: "foo", factory: { _ in CustomHandler() })
        #expect(logger2.handler is CustomHandler, "expected custom log handler")
    }

    @Test func allLogLevelsExceptCriticalCanBeBlocked() {
        let testLogging = TestLogging()

        var logger = Logger(
            label: "\(#function)",
            factory: {
                testLogging.make(label: $0)
            }
        )
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

    @Test func allLogLevelsWork() {
        let testLogging = TestLogging()

        var logger = Logger(
            label: "\(#function)",
            factory: {
                testLogging.make(label: $0)
            }
        )
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

    @Test func allLogLevelByFunctionRefWithSource() {
        let testLogging = TestLogging()

        var logger = Logger(
            label: "\(#function)",
            factory: {
                testLogging.make(label: $0)
            }
        )
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

    @Test func allLogLevelByFunctionRefWithoutSource() {
        let testLogging = TestLogging()

        var logger = Logger(
            label: "\(#function)",
            factory: {
                testLogging.make(label: $0)
            }
        )
        logger.logLevel = .trace

        let trace = logger.trace(_:metadata:file:function:line:)
        let debug = logger.debug(_:metadata:file:function:line:)
        let info = logger.info(_:metadata:file:function:line:)
        let notice = logger.notice(_:metadata:file:function:line:)
        let warning = logger.warning(_:metadata:file:function:line:)
        let error = logger.error(_:metadata:file:function:line:)
        let critical = logger.critical(_:metadata:file:function:line:)

        trace("yes: trace", [:], #fileID, #function, #line)
        debug("yes: debug", [:], #fileID, #function, #line)
        info("yes: info", [:], #fileID, #function, #line)
        notice("yes: notice", [:], #fileID, #function, #line)
        warning("yes: warning", [:], #fileID, #function, #line)
        error("yes: error", [:], #fileID, #function, #line)
        critical("yes: critical", [:], #fileID, #function, #line)

        testLogging.history.assertExist(level: .trace, message: "yes: trace")
        testLogging.history.assertExist(level: .debug, message: "yes: debug")
        testLogging.history.assertExist(level: .info, message: "yes: info")
        testLogging.history.assertExist(level: .notice, message: "yes: notice")
        testLogging.history.assertExist(level: .warning, message: "yes: warning")
        testLogging.history.assertExist(level: .error, message: "yes: error")
        testLogging.history.assertExist(level: .critical, message: "yes: critical")
    }

    @Test func logsEmittedFromSubdirectoryGetCorrectModuleInNewerSwifts() {
        let testLogging = TestLogging()

        var logger = Logger(
            label: "\(#function)",
            factory: {
                testLogging.make(label: $0)
            }
        )
        logger.logLevel = .trace

        emitLogMessage("hello", to: logger)

        let moduleName = "LoggingTests"  // the actual name

        testLogging.history.assertExist(level: .trace, message: "hello", source: moduleName)
        testLogging.history.assertExist(level: .debug, message: "hello", source: moduleName)
        testLogging.history.assertExist(level: .info, message: "hello", source: moduleName)
        testLogging.history.assertExist(level: .notice, message: "hello", source: moduleName)
        testLogging.history.assertExist(level: .warning, message: "hello", source: moduleName)
        testLogging.history.assertExist(level: .error, message: "hello", source: moduleName)
        testLogging.history.assertExist(level: .critical, message: "hello", source: moduleName)
    }

    @Test func logMessageWithStringInterpolation() {
        let testLogging = TestLogging()

        var logger = Logger(
            label: "\(#function)",
            factory: {
                testLogging.make(label: $0)
            }
        )
        logger.logLevel = .debug

        let someInt = Int.random(in: 23..<42)
        logger.debug("My favourite number is \(someInt) and not \(someInt - 1)")
        testLogging.history.assertExist(
            level: .debug,
            message: "My favourite number is \(someInt) and not \(someInt - 1)" as String
        )
    }

    @Test func loggingAString() {
        let testLogging = TestLogging()

        var logger = Logger(
            label: "\(#function)",
            factory: {
                testLogging.make(label: $0)
            }
        )
        logger.logLevel = .debug

        let anActualString: String = "hello world!"
        // We can't stick an actual String in here because we expect a Logger.Message. If we want to log an existing
        // `String`, we can use string interpolation. The error you'll get trying to use the String directly is:
        //
        //     error: Cannot convert value of type 'String' to expected argument type 'Logger.Message'
        logger.debug("\(anActualString)")
        testLogging.history.assertExist(level: .debug, message: "hello world!")
    }

    @Test func multiplexMetadataProviderMergesInSpecifiedOrder() {
        let logging = TestLogging()

        let providerA = Logger.MetadataProvider { ["provider": "a", "a": "foo"] }
        let providerB = Logger.MetadataProvider { ["provider": "b", "b": "bar"] }
        let logger = Logger(
            label: #function,
            factory: { label in
                logging.makeWithMetadataProvider(label: label, metadataProvider: .multiplex([providerA, providerB]))
            }
        )

        logger.log(level: .info, "test", metadata: ["one-off": "42"])

        logging.history.assertExist(
            level: .info,
            message: "test",
            metadata: ["provider": "b", "a": "foo", "b": "bar", "one-off": "42"]
        )
    }

    @Test func multiplexerIsValue() {
        let multi = MultiplexLogHandler([
            StreamLogHandler.standardOutput(label: "x"), StreamLogHandler.standardOutput(label: "y"),
        ])
        let logger1: Logger = {
            var logger = Logger(
                label: "foo",
                factory: { _ in
                    print("new multi")
                    return multi
                }
            )
            logger.logLevel = .debug
            logger[metadataKey: "only-on"] = "first"
            return logger
        }()
        #expect(.debug == logger1.logLevel)
        var logger2 = logger1
        logger2.logLevel = .error
        logger2[metadataKey: "only-on"] = "second"
        #expect(.error == logger2.logLevel)
        #expect(.debug == logger1.logLevel)
        #expect("first" == logger1[metadataKey: "only-on"])
        #expect("second" == logger2[metadataKey: "only-on"])
        logger1.error("hey")
    }

    /// Protects an object such that it can only be accessed while holding a lock.
    private final class LockedValueBox<Value: Sendable>: @unchecked Sendable {
        private let lock = Lock()
        private var storage: Value

        init(initialValue: Value) {
            self.storage = initialValue
        }

        func withLock<Result>(_ operation: (Value) -> Result) -> Result {
            self.lock.withLock {
                operation(self.storage)
            }
        }

        func withLockMutating(_ operation: (inout Value) -> Void) {
            self.lock.withLockVoid {
                operation(&self.storage)
            }
        }

        var underlying: Value {
            get { self.withLock { $0 } }
            set { self.withLockMutating { $0 = newValue } }
        }
    }

    @Test func loggerWithGlobalOverride() {
        struct LogHandlerWithGlobalLogLevelOverride: LogHandler {
            // the static properties hold the globally overridden log level (if overridden)
            private static let overrideLogLevel = LockedValueBox<Logger.Level?>(initialValue: nil)

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
                    LogHandlerWithGlobalLogLevelOverride.overrideLogLevel.underlying ?? self._logLevel
                }
                // we set the log level whenever we're asked (note: this might not have an effect if globally
                // overridden)
                set {
                    self._logLevel = newValue
                }
            }

            func log(
                level: Logger.Level,
                message: Logger.Message,
                metadata: Logger.Metadata?,
                source: String,
                file: String,
                function: String,
                line: UInt
            ) {
                self.recorder.record(level: level, metadata: metadata, message: message, source: source)
            }

            subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
                get {
                    self.metadata[metadataKey]
                }
                set(newValue) {
                    self.metadata[metadataKey] = newValue
                }
            }

            // this is the function to globally override the log level, it is not part of the `LogHandler` protocol
            static func overrideGlobalLogLevel(_ logLevel: Logger.Level) {
                LogHandlerWithGlobalLogLevelOverride.overrideLogLevel.underlying = logLevel
            }
        }

        let logRecorder = Recorder()

        var logger1 = Logger(
            label: "logger-\(#file):\(#line)",
            factory: { _ in
                LogHandlerWithGlobalLogLevelOverride(recorder: logRecorder)
            }
        )
        var logger2 = logger1
        logger1.logLevel = .warning
        logger1[metadataKey: "only-on"] = "first"
        logger2.logLevel = .error
        logger2[metadataKey: "only-on"] = "second"
        #expect(.error == logger2.logLevel)
        #expect(.warning == logger1.logLevel)
        #expect("first" == logger1[metadataKey: "only-on"])
        #expect("second" == logger2[metadataKey: "only-on"])

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

    @Test func logLevelCases() {
        let levels = Logger.Level.allCases
        #expect(7 == levels.count)
    }

    @Test func logLevelOrdering() {
        #expect(Logger.Level.trace < Logger.Level.debug)
        #expect(Logger.Level.trace < Logger.Level.info)
        #expect(Logger.Level.trace < Logger.Level.notice)
        #expect(Logger.Level.trace < Logger.Level.warning)
        #expect(Logger.Level.trace < Logger.Level.error)
        #expect(Logger.Level.trace < Logger.Level.critical)
        #expect(Logger.Level.debug < Logger.Level.info)
        #expect(Logger.Level.debug < Logger.Level.notice)
        #expect(Logger.Level.debug < Logger.Level.warning)
        #expect(Logger.Level.debug < Logger.Level.error)
        #expect(Logger.Level.debug < Logger.Level.critical)
        #expect(Logger.Level.info < Logger.Level.notice)
        #expect(Logger.Level.info < Logger.Level.warning)
        #expect(Logger.Level.info < Logger.Level.error)
        #expect(Logger.Level.info < Logger.Level.critical)
        #expect(Logger.Level.notice < Logger.Level.warning)
        #expect(Logger.Level.notice < Logger.Level.error)
        #expect(Logger.Level.notice < Logger.Level.critical)
        #expect(Logger.Level.warning < Logger.Level.error)
        #expect(Logger.Level.warning < Logger.Level.critical)
        #expect(Logger.Level.error < Logger.Level.critical)
    }

    @Test(arguments: Logger.Level.allCases) func logLevelDescription(level: Logger.Level) {
        #expect(level.description == level.rawValue)
        #expect(Logger.Level(level.rawValue.uppercased()) == level)
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

    @Test func streamLogHandlerWritesToAStream() {
        let interceptStream = InterceptStream()
        let log = Logger(
            label: "test",
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)")

        let messageSucceeded = interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines)
            .hasSuffix(testString)

        #expect(messageSucceeded ?? false)
        #expect(interceptStream.strings.count == 1)
    }

    @Test func streamLogHandlerOutputFormat() {
        let interceptStream = InterceptStream()
        let label = "testLabel"
        let source = "testSource"
        let log = Logger(
            label: label,
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)", source: source)

        let pattern =
            "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+|-)\\d{4}\\s\(Logger.Level.critical)\\s\(label):\\s\\[\(source)\\]\\s\(testString)$"

        let messageSucceeded =
            interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines).range(
                of: pattern,
                options: .regularExpression
            ) != nil

        #expect(messageSucceeded)
        #expect(interceptStream.strings.count == 1)
    }

    @Test func streamLogHandlerOutputFormatWithEmptyLabel() {
        let interceptStream = InterceptStream()
        let source = "testSource"
        let log = Logger(
            label: "",
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)", source: source)

        let pattern =
            "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+|-)\\d{4}\\s\(Logger.Level.critical):\\s\\[\(source)\\]\\s\(testString)$"

        let messageSucceeded =
            interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines).range(
                of: pattern,
                options: .regularExpression
            ) != nil

        #expect(messageSucceeded)
        #expect(interceptStream.strings.count == 1)
    }

    @Test func streamLogHandlerOutputFormatWithMetaData() {
        let interceptStream = InterceptStream()
        let label = "testLabel"
        let source = "testSource"
        let log = Logger(
            label: label,
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)", metadata: ["test": "test"], source: source)

        let pattern =
            "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+|-)\\d{4}\\s\(Logger.Level.critical)\\s\(label):\\stest=test\\s\\[\(source)\\]\\s\(testString)$"

        let messageSucceeded =
            interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines).range(
                of: pattern,
                options: .regularExpression
            ) != nil

        #expect(messageSucceeded)
        #expect(interceptStream.strings.count == 1)
    }

    @Test func streamLogHandlerOutputFormatWithOrderedMetadata() {
        let interceptStream = InterceptStream()
        let log = Logger(
            label: "testLabel",
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)", metadata: ["a": "a0", "b": "b0"])
        log.critical("\(testString)", metadata: ["b": "b1", "a": "a1"])

        #expect(interceptStream.strings.count == 2)
        guard interceptStream.strings.count == 2 else {
            Issue.record("Intercepted \(interceptStream.strings.count) logs, expected 2")
            return
        }

        #expect(interceptStream.strings[0].contains("a=a0 b=b0"), "LINES: \(interceptStream.strings[0])")
        #expect(interceptStream.strings[1].contains("a=a1 b=b1"), "LINES: \(interceptStream.strings[1])")
    }

    @Test func streamLogHandlerWritesIncludeMetadataProviderMetadata() {
        let interceptStream = InterceptStream()
        let log = Logger(
            label: "test",
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream, metadataProvider: .exampleProvider)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)")

        let messageSucceeded = interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines)
            .hasSuffix(testString)

        #expect(messageSucceeded ?? false)
        #expect(interceptStream.strings.count == 1)
        let message = interceptStream.strings.first!
        #expect(message.contains("example=example-value"), "message must contain metadata, was: \(message)")
    }

    @Test func stdioOutputStreamWrite() {
        self.withWriteReadFDsAndReadBuffer { writeFD, readFD, readBuffer in
            let logStream = StdioOutputStream(file: writeFD, flushMode: .always)
            let log = Logger(
                label: "test",
                factory: {
                    StreamLogHandler(label: $0, stream: logStream)
                }
            )
            let testString = "hello\u{0} world"
            log.critical("\(testString)")

            #if os(Windows)
            let size = _read(readFD, readBuffer, 256)
            #else
            let size = read(readFD, readBuffer, 256)
            #endif

            let output = String(
                decoding: UnsafeRawBufferPointer(start: UnsafeRawPointer(readBuffer), count: numericCast(size)),
                as: UTF8.self
            )
            let messageSucceeded = output.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(testString)
            #expect(messageSucceeded)
        }
    }

    @Test func stdioOutputStreamFlush() {
        // flush on every statement
        self.withWriteReadFDsAndReadBuffer { writeFD, readFD, readBuffer in
            let logStream = StdioOutputStream(file: writeFD, flushMode: .always)
            Logger(
                label: "test",
                factory: {
                    StreamLogHandler(label: $0, stream: logStream)
                }
            ).critical("test")

            #if os(Windows)
            let size = _read(readFD, readBuffer, 256)
            #else
            let size = read(readFD, readBuffer, 256)
            #endif
            #expect(size > -1, "expected flush")

            logStream.flush()

            #if os(Windows)
            let size2 = _read(readFD, readBuffer, 256)
            #else
            let size2 = read(readFD, readBuffer, 256)
            #endif
            #expect(size2 == -1, "expected no flush")
        }
        // default flushing
        self.withWriteReadFDsAndReadBuffer { writeFD, readFD, readBuffer in
            let logStream = StdioOutputStream(file: writeFD, flushMode: .undefined)
            Logger(
                label: "test",
                factory: {
                    StreamLogHandler(label: $0, stream: logStream)
                }
            ).critical("test")

            #if os(Windows)
            let size = _read(readFD, readBuffer, 256)
            #else
            let size = read(readFD, readBuffer, 256)
            #endif
            #expect(size == -1, "expected no flush")

            logStream.flush()

            #if os(Windows)
            let size2 = _read(readFD, readBuffer, 256)
            #else
            let size2 = read(readFD, readBuffer, 256)
            #endif
            #expect(size2 > -1, "expected flush")
        }
    }

    func withWriteReadFDsAndReadBuffer(_ body: (CFilePointer, CInt, UnsafeMutablePointer<Int8>) -> Void) {
        var fds: [Int32] = [-1, -1]
        #if os(Windows)
        fds.withUnsafeMutableBufferPointer {
            let err = _pipe($0.baseAddress, 256, _O_BINARY)
            #expect(err == 0, "_pipe failed \(err)")
        }
        guard let writeFD = _fdopen(fds[1], "w") else {
            Issue.record("Failed to open file")
            return
        }
        #else
        fds.withUnsafeMutableBufferPointer { ptr in
            let err = pipe(ptr.baseAddress!)
            #expect(err == 0, "pipe failed \(err)")
        }
        guard let writeFD = fdopen(fds[1], "w") else {
            Issue.record("Failed to open file")
            return
        }
        #endif

        let writeBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        defer {
            writeBuffer.deinitialize(count: 256)
            writeBuffer.deallocate()
        }

        var err = setvbuf(writeFD, writeBuffer, _IOFBF, 256)
        #expect(err == 0, "setvbuf failed \(err)")

        let readFD = fds[0]
        #if os(Windows)
        let hPipe: HANDLE = HANDLE(bitPattern: _get_osfhandle(readFD))!
        #expect(hPipe != INVALID_HANDLE_VALUE)

        var dwMode: DWORD = DWORD(PIPE_NOWAIT)
        let bSucceeded = SetNamedPipeHandleState(hPipe, &dwMode, nil, nil)
        #expect(bSucceeded)
        #else
        err = fcntl(readFD, F_SETFL, fcntl(readFD, F_GETFL) | O_NONBLOCK)
        #expect(err == 0, "fcntl failed \(err)")
        #endif

        let readBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        defer {
            readBuffer.deinitialize(count: 256)
            readBuffer.deallocate()
        }

        // the actual test
        body(writeFD, readFD, readBuffer)

        for fd in fds {
            #if os(Windows)
            _close(fd)
            #else
            close(fd)
            #endif
        }
    }

    @Test func overloadingError() {
        struct Dummy: Error, LocalizedError {
            var errorDescription: String? {
                "errorDescription"
            }
        }
        // create test logging impl, do not bootstrap global LoggingSystem
        let logging = TestLogging()

        var logger = Logger(
            label: "test",
            factory: {
                logging.make(label: $0)
            }
        )
        logger.logLevel = .error
        logger.error(error: Dummy())

        logging.history.assertExist(level: .error, message: "errorDescription")
    }

    @Test func compileInitializeStandardStreamLogHandlersWithMetadataProviders() {
        // avoid "unreachable code" warnings
        let dontExecute = Int.random(in: 100...200) == 1
        guard dontExecute else {
            return
        }

        // default usage
        LoggingSystem.bootstrap { (label: String) in StreamLogHandler.standardOutput(label: label) }
        LoggingSystem.bootstrap { (label: String) in StreamLogHandler.standardError(label: label) }

        // with metadata handler, explicitly, public api
        LoggingSystem.bootstrap(
            { label, metadataProvider in
                StreamLogHandler.standardOutput(label: label, metadataProvider: metadataProvider)
            },
            metadataProvider: .exampleProvider
        )
        LoggingSystem.bootstrap(
            { label, metadataProvider in
                StreamLogHandler.standardError(label: label, metadataProvider: metadataProvider)
            },
            metadataProvider: .exampleProvider
        )

        // with metadata handler, still pretty
        LoggingSystem.bootstrap(
            { (label: String, metadataProvider: Logger.MetadataProvider?) in
                StreamLogHandler.standardOutput(label: label, metadataProvider: metadataProvider)
            },
            metadataProvider: .exampleProvider
        )
        LoggingSystem.bootstrap(
            { (label: String, metadataProvider: Logger.MetadataProvider?) in
                StreamLogHandler.standardError(label: label, metadataProvider: metadataProvider)
            },
            metadataProvider: .exampleProvider
        )
    }

    @Test func loggerIsJustHoldingASinglePointer() {
        let expectedSize = MemoryLayout<UnsafeRawPointer>.size
        #expect(MemoryLayout<Logger>.size == expectedSize)
    }

    @Test func loggerCopyOnWrite() {
        var logger1 = Logger(label: "foo")
        logger1.logLevel = .error
        var logger2 = logger1
        logger2.logLevel = .trace
        #expect(.error == logger1.logLevel)
        #expect(.trace == logger2.logLevel)
    }
}

extension Logger {
    public func error(
        error: any Error,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        self.error("\(error.localizedDescription)", metadata: metadata(), file: file, function: function, line: line)
    }
}

extension Logger.MetadataProvider {
    static var exampleProvider: Self {
        .init { ["example": .string("example-value")] }
    }

    static func constant(_ metadata: Logger.Metadata) -> Self {
        .init { metadata }
    }
}

// Sendable

// used to test logging metadata which requires Sendable conformance
// @unchecked Sendable since manages it own state
extension LoggingTest.LazyMetadataBox: @unchecked Sendable {}

// used to test logging stream which requires Sendable conformance
// @unchecked Sendable since manages it own state
extension LoggingTest.InterceptStream: @unchecked Sendable {}
