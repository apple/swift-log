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

final class MetadataProviderTest: XCTestCase {
    func testLoggingMergesOneOffMetadataWithProvidedMetadataFromExplicitlyPassed() throws {
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal(logging.makeWithMetadataProvider,
                                        metadataProvider: .init { ["common": "initial"]
        })

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

    func testLogHandlerThatDidNotImplementProvidersButSomeoneAttemptsToSetOneOnIt() {
        #if DEBUG
        // we only emit these warnings in debug mode
        let logging = TestLogging()
        var handler = LogHandlerThatDidNotImplementMetadataProviders(testLogging: logging)

        handler.metadataProvider = .simpleTestProvider

        logging.history.assertExist(level: .warning, message: "Attempted to set metadataProvider on LogHandlerThatDidNotImplementMetadataProviders that did not implement support for them. Please contact the log handler maintainer to implement metadata provider support.", source: "Logging")

        let countBefore = logging.history.entries.count
        handler.metadataProvider = .simpleTestProvider
        XCTAssertEqual(countBefore, logging.history.entries.count, "Should only log the warning once")
        #endif
    }

    func testLogHandlerThatDidImplementProvidersButSomeoneAttemptsToSetOneOnIt() {
        #if DEBUG
        // we only emit these warnings in debug mode
        let logging = TestLogging()
        var handler = LogHandlerThatDidImplementMetadataProviders(testLogging: logging)

        handler.metadataProvider = .simpleTestProvider

        logging.history.assertNotExist(level: .warning, message: "Attempted to set metadataProvider on LogHandlerThatDidImplementMetadataProviders that did not implement support for them. Please contact the log handler maintainer to implement metadata provider support.", source: "Logging")
        #endif
    }
}

extension Logger.MetadataProvider {
    static var simpleTestProvider: Logger.MetadataProvider {
        return Logger.MetadataProvider {
            return ["test": "provided"]
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
            return nil
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

public struct LogHandlerThatDidImplementMetadataProviders: LogHandler {
    let testLogging: TestLogging
    init(testLogging: TestLogging) {
        self.testLogging = testLogging
    }

    public subscript(metadataKey _: String) -> Logging.Logger.Metadata.Value? {
        get {
            return nil
        }
        set(newValue) {
            // ignore
        }
    }

    public var metadata: Logging.Logger.Metadata = [:]

    public var logLevel: Logging.Logger.Level = .trace

    public var metadataProvider: Logger.MetadataProvider?

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
