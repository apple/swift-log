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

enum TestLocals {
    #if swift(>=5.5) && canImport(_Concurrency)
    @TaskLocal
    static var testID: String?
    @TaskLocal
    static var onlyLocalID: String?
    @TaskLocal
    static var onlyExplicitlyProvidedID: String?
    #endif
}

final class MetadataProviderTest: XCTestCase {
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testLoggingCallsMetadataProviderWithTaskLocal() throws {
        #if swift(>=5.5) && canImport(_Concurrency)
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal(logging.makeWithMetadataProvider)

        var logger = Logger(label: #function, metadataProvider: .init {
            guard let testID = TestLocals.testID else {
                XCTFail("Expected `testID` to be passed along to the metadata provider.")
                return [:]
            }
            return ["provider": .string(testID)]
        })
        logger.logLevel = .trace

        TestLocals.$testID.withValue("42") {
            logger.trace("test")
            logger.debug("test")
            logger.info("test")
            logger.notice("test")
            logger.warning("test")
            logger.error("test")
            logger.critical("test")
        }

        logging.history.assertExist(level: .trace, message: "test", metadata: ["provider": "42"])
        logging.history.assertExist(level: .debug, message: "test", metadata: ["provider": "42"])
        logging.history.assertExist(level: .info, message: "test", metadata: ["provider": "42"])
        logging.history.assertExist(level: .notice, message: "test", metadata: ["provider": "42"])
        logging.history.assertExist(level: .warning, message: "test", metadata: ["provider": "42"])
        logging.history.assertExist(level: .error, message: "test", metadata: ["provider": "42"])
        logging.history.assertExist(level: .critical, message: "test", metadata: ["provider": "42"])
        #endif
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testLoggingMergesOneOffMetadataWithProvidedMetadataFromTaskLocal() throws {
        #if swift(>=5.5) && canImport(_Concurrency)
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal(logging.makeWithMetadataProvider)

        let logger = Logger(label: #function, metadataProvider: .init {
            [
                "common": "provider",
                "provider": "42",
            ]
        })

        TestLocals.$testID.withValue("ignore-this") {
            logger.log(level: .info, "test", metadata: ["one-off": "42", "common": "one-off"])
        }

        logging.history.assertExist(level: .info,
                                    message: "test",
                                    metadata: ["common": "one-off", "one-off": "42", "provider": "42"])
        #endif
    }

    func testLoggingMergesOneOffMetadataWithProvidedMetadataFromExplicitlyPassed() throws {
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal(logging.makeWithMetadataProvider)

        let logger = Logger(label: #function, metadataProvider: .init {
            [
                "common": "provider",
                "provider": "42",
            ]
        })

        logger.log(level: .info, "test", metadata: ["one-off": "42", "common": "one-off"])

        logging.history.assertExist(level: .info,
                                    message: "test",
                                    metadata: ["common": "one-off", "one-off": "42", "provider": "42"])
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testLoggingIncludesExplicitOverTaskLocal() {
        #if swift(>=5.5) && canImport(_Concurrency)
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal(logging.makeWithMetadataProvider)

        var logger = Logger(label: #function, metadataProvider: .init {
            var metadata: Logger.Metadata = [:]

            if let testID = TestLocals.testID {
                metadata["overridden-contextual"] = .string(testID)
            }
            if let onlyLocal = TestLocals.onlyLocalID {
                metadata["only-local"] = .string(onlyLocal)
            }
            if let onlyExplicitlyProvidedToHandler = TestLocals.onlyExplicitlyProvidedID {
                metadata["only-explicitly"] = .string(onlyExplicitlyProvidedToHandler)
            }
            return metadata
        })
        logger.logLevel = .trace

        TestLocals.$testID.withValue("task-local") {
            TestLocals.$onlyLocalID.withValue("task-local") {
                logger[metadataKey: "overridden-contextual"] = "will-be-overridden"
                logger[metadataKey: "only-explicitly"] = "provided-to-handler"
                logger.trace("test", metadata: ["one-off": "42"])
                logger.debug("test", metadata: ["one-off": "42"])
                logger.info("test", metadata: ["one-off": "42"])
                logger.notice("test", metadata: ["one-off": "42"])
                logger.warning("test", metadata: ["one-off": "42"])
                logger.error("test", metadata: ["one-off": "42"])
                logger.critical("test", metadata: ["one-off": "42"])
            }
        }

        // ["one-off": 42, "only-local": task-local, "only-explicitly": provided-to-handler, "overridden-contextual": task-local]
        let expectedMetadata: Logger.Metadata = [
            // explicitly set on handler by `logger.provideMetadata`:
            "only-explicitly": "provided-to-handler",
            // passed in-line by end user at log statement level:
            "one-off": "42",
            // contextual metadata, if present, still wins over the provided to handler,
            // which allows for "default value if no contextual is present" (which the "only-explicit" is an example of):
            "overridden-contextual": "task-local",
            // task-local is picked up as usual if no conflicts:
            "only-local": "task-local",
        ]

        logging.history.assertExist(level: .trace, message: "test", metadata: expectedMetadata)
        logging.history.assertExist(level: .debug, message: "test", metadata: expectedMetadata)
        logging.history.assertExist(level: .info, message: "test", metadata: expectedMetadata)
        logging.history.assertExist(level: .notice, message: "test", metadata: expectedMetadata)
        logging.history.assertExist(level: .warning, message: "test", metadata: expectedMetadata)
        logging.history.assertExist(level: .error, message: "test", metadata: expectedMetadata)
        logging.history.assertExist(level: .critical, message: "test", metadata: expectedMetadata)
        #endif
    }

    func testLogHandlerThatDidNotImplementProvidersButSomeoneAttemptsToSetOneOnIt() {
        let logging = TestLogging()
        var handler = LogHandlerThatDidNotImplementMetadataProviders(testLogging: logging)

        handler.metadataProvider = .simpleTestProvider

        logging.history.assertExist(level: .warning, message: "Attempted to set metadataProvider on LogHandlerThatDidNotImplementMetadataProviders that did not implement support for them. Please contact the log handler maintainer to implement metadata provider support.", source: "Logging")
    }
}

extension Logger.MetadataProvider {
    static var simpleTestProvider: Self {
        .init {
            ["test": "provided"]
        }
    }
}

public struct LogHandlerThatDidNotImplementMetadataProviders: LogHandler {
    let testLogging: TestLogging
    init(testLogging: TestLogging) {
        self.testLogging = testLogging
    }

    public subscript(metadataKey _: String) -> Logging.Logger.Metadata.Value? {
        get {
            nil
        }
        set(newValue) {
            // ignore
        }
    }

    public var metadata: Logging.Logger.Metadata = [:]

    public var logLevel: Logging.Logger.Level = .trace

    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata?,
                    source: String,
                    file: String,
                    function: String,
                    line: UInt) {
        self.testLogging.make(label: "fake").log(level: level, message: message, metadata: metadata, source: source, file: file, function: function, line: line)
    }
}
