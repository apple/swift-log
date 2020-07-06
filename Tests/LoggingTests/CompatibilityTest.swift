//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/* NOT @testable */ import Logging
import XCTest

final class CompatibilityTest: XCTestCase {
    func testAllLogLevelsWorkWithOldSchoolLogHandlerWorks() {
        let testLogging = OldSchoolTestLogging()

        var logger = Logger(label: "\(#function)", factory: testLogging.make)
        logger.logLevel = .trace

        logger.trace("yes: trace")
        logger.debug("yes: debug")
        logger.info("yes: info")
        logger.notice("yes: notice")
        logger.warning("yes: warning")
        logger.error("yes: error")
        logger.critical("yes: critical", source: "any also with some new argument that isn't propagated")

        // Please note that the source is _not_ propagated (because the backend doesn't support it).
        testLogging.history.assertExist(level: .trace, message: "yes: trace", source: "no source")
        testLogging.history.assertExist(level: .debug, message: "yes: debug", source: "no source")
        testLogging.history.assertExist(level: .info, message: "yes: info", source: "no source")
        testLogging.history.assertExist(level: .notice, message: "yes: notice", source: "no source")
        testLogging.history.assertExist(level: .warning, message: "yes: warning", source: "no source")
        testLogging.history.assertExist(level: .error, message: "yes: error", source: "no source")
        testLogging.history.assertExist(level: .critical, message: "yes: critical", source: "no source")
    }
}

private struct OldSchoolTestLogging {
    private let _config = Config() // shared among loggers
    private let recorder = Recorder() // shared among loggers

    func make(label: String) -> LogHandler {
        return OldSchoolLogHandler(label: label,
                                   config: self.config,
                                   recorder: self.recorder,
                                   metadata: [:],
                                   logLevel: .info)
    }

    var config: Config { return self._config }
    var history: History { return self.recorder }
}

private struct OldSchoolLogHandler: LogHandler {
    var label: String
    let config: Config
    let recorder: Recorder

    func make(label: String) -> LogHandler {
        return TestLogHandler(label: label, config: self.config, recorder: self.recorder)
    }

    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {
        self.recorder.record(level: level, metadata: metadata, message: message, source: "no source")
    }

    subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[metadataKey]
        }
        set {
            self.metadata[metadataKey] = newValue
        }
    }

    var metadata: Logger.Metadata

    var logLevel: Logger.Level
}
