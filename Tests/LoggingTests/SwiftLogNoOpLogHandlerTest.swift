//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Testing

@testable import Logging

struct SwiftLogNoOpLogHandlerTest {
    @Test func initWithNoArguments() {
        let handler = SwiftLogNoOpLogHandler()
        #expect(handler.logLevel == .critical)
        #expect(handler.metadata == [:])
    }

    @Test func initWithLabel() {
        let handler = SwiftLogNoOpLogHandler("some.label")
        #expect(handler.logLevel == .critical)
        #expect(handler.metadata == [:])
    }

    @Test func logLevelIgnoresMutations() {
        var handler = SwiftLogNoOpLogHandler()
        handler.logLevel = .trace
        #expect(handler.logLevel == .critical)
    }

    @Test func metadataIgnoresMutations() {
        var handler = SwiftLogNoOpLogHandler()
        handler.metadata = ["key": "value"]
        #expect(handler.metadata == [:])
    }

    @Test func metadataSubscriptAlwaysReturnsNil() {
        var handler = SwiftLogNoOpLogHandler()
        #expect(handler[metadataKey: "key"] == nil)
        handler[metadataKey: "key"] = "value"
        #expect(handler[metadataKey: "key"] == nil)
    }

    @Test func logEventDoesNotCrash() {
        let handler = SwiftLogNoOpLogHandler()
        let event = LogEvent(
            level: .critical,
            message: "message",
            metadata: ["key": "value"],
            source: "test",
            file: #file,
            function: #function,
            line: #line
        )
        handler.log(event: event)
    }

    @Test func allLogLevelsDoNotCrash() {
        var logger = Logger(label: "noop.test", factory: { _ in SwiftLogNoOpLogHandler() })
        logger[metadataKey: "key"] = "value"
        logger.trace("trace message")
        logger.debug("debug message")
        logger.info("info message")
        logger.notice("notice message")
        logger.warning("warning message")
        logger.error("error message")
        logger.critical("critical message")
    }
}
