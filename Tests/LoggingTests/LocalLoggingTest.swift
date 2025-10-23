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

import Dispatch
import Testing

@testable import Logging

struct LocalLoggerTest {
    @Test func traceAndAbove() throws {
        // create test logging impl, do not bootstrap global LoggingSystem
        let logging = TestLogging()

        // change global test logging config to log trace and above,
        // local logging context will be modified to debug
        logging.config.set(value: Logger.Level.trace)
        // run our program
        let context = Context { logging.make(label: $0) }
        Struct1().doSomething(context: context)
        // test results
        logging.history.assertExist(level: .debug, message: "Struct1::doSomething", source: "LoggingTests")
        logging.history.assertNotExist(level: .debug, message: "Struct1::doSomethingElse")
        logging.history.assertExist(level: .info, message: "Struct2::doSomething")
        logging.history.assertExist(level: .info, message: "Struct2::doSomethingElse")
        logging.history.assertExist(level: .error, message: "Struct3::doSomething", metadata: ["bar": "baz"])
        logging.history.assertExist(level: .error, message: "Struct3::doSomethingElse", metadata: ["bar": "baz"])
        logging.history.assertExist(level: .warning, message: "Struct3::doSomethingElseAsync", metadata: ["bar": "baz"])
        logging.history.assertExist(
            level: .debug,
            message: "Struct3::doSomethingElse::Local",
            metadata: ["bar": "baz", "baz": "qux"]
        )
        logging.history.assertExist(level: .debug, message: "Struct3::doSomethingElse::end", metadata: ["bar": "baz"])
        logging.history.assertNotExist(
            level: .trace,
            message: "Struct3::doSomethingElse::end::lastLine",
            metadata: ["bar": "baz"]
        )
        logging.history.assertExist(level: .debug, message: "Struct3::doSomething::end", metadata: ["bar": "baz"])
        logging.history.assertExist(level: .debug, message: "Struct2::doSomethingElse::end")
        logging.history.assertNotExist(level: .trace, message: "Struct2::doSomethingElse::end::lastLine")
        logging.history.assertExist(level: .debug, message: "Struct1::doSomethingElse::end")
        logging.history.assertNotExist(level: .trace, message: "Struct1::doSomethingElse::end::lastLine")
        logging.history.assertExist(level: .debug, message: "Struct1::doSomething::end")
    }

    @Test func errorAndAbove() throws {
        // create test logging impl, do not bootstrap global LoggingSystem
        let logging = TestLogging()

        // change test logging config to log errors and above
        logging.config.set(value: Logger.Level.error)
        // run our program
        let context = Context { logging.make(label: $0) }
        Struct1().doSomething(context: context)
        // test results
        // global context
        logging.history.assertNotExist(level: .debug, message: "Struct1::doSomething")
        // global context
        logging.history.assertNotExist(level: .debug, message: "Struct1::doSomethingElse")
        // local context
        logging.history.assertExist(level: .info, message: "Struct2::doSomething")
        // local context
        logging.history.assertExist(level: .info, message: "Struct2::doSomethingElse")
        // local context
        logging.history.assertExist(level: .error, message: "Struct3::doSomething", metadata: ["bar": "baz"])
        // local context
        logging.history.assertExist(level: .error, message: "Struct3::doSomethingElse", metadata: ["bar": "baz"])
        // local context
        logging.history.assertExist(level: .warning, message: "Struct3::doSomethingElseAsync", metadata: ["bar": "baz"])
        // global context
        logging.history.assertNotExist(level: .info, message: "TestLibrary::doSomething")
        // global context
        logging.history.assertNotExist(level: .info, message: "TestLibrary::doSomethingAsync")
        // hyper local .debug context
        logging.history.assertExist(
            level: .debug,
            message: "Struct3::doSomethingElse::Local",
            metadata: ["bar": "baz", "baz": "qux"]
        )
        // local .debug context
        logging.history.assertExist(level: .debug, message: "Struct3::doSomethingElse::end", metadata: ["bar": "baz"])
        logging.history.assertNotExist(
            level: .trace,
            message: "Struct3::doSomethingElse::end::lastLine",
            metadata: ["bar": "baz"]
        )
        // local .debug context
        logging.history.assertExist(level: .debug, message: "Struct2::doSomethingElse::end")
        logging.history.assertNotExist(level: .trace, message: "Struct2::doSomethingElse::end::lastLine")
        // local context
        logging.history.assertExist(level: .debug, message: "Struct3::doSomething::end", metadata: ["bar": "baz"])
        // global context
        logging.history.assertNotExist(level: .debug, message: "Struct1::doSomethingElse::end")
        logging.history.assertNotExist(level: .trace, message: "Struct1::doSomethingElse::end::lastLine")
        // global context
        logging.history.assertNotExist(level: .debug, message: "Struct1::doSomething::end")
    }
}

//  systems that follow the context pattern  need to implement something like this
private struct Context {
    var logger: Logger

    init(_ factory: (String) -> any LogHandler) {
        self.logger = Logger(label: "LocalLoggerTest::ContextLogger", factory: factory)
    }

    // since logger is a value type, we can reuse our copy to manage logLevel
    var logLevel: Logger.Level {
        get { self.logger.logLevel }
        set { self.logger.logLevel = newValue }
    }

    // since logger is a value type, we can reuse our copy to manage metadata
    subscript(metadataKey: String) -> Logger.Metadata.Value? {
        get { self.logger[metadataKey: metadataKey] }
        set { self.logger[metadataKey: metadataKey] = newValue }
    }
}

private struct Struct1 {
    func doSomething(context: Context) {
        context.logger.debug("Struct1::doSomething")
        self.doSomethingElse(context: context)
        context.logger.debug("Struct1::doSomething::end")
    }

    private func doSomethingElse(context: Context) {
        let originalContext = context
        var context = context
        context.logger.logLevel = .warning
        context.logger.debug("Struct1::doSomethingElse")
        Struct2().doSomething(context: context)
        originalContext.logger.debug("Struct1::doSomethingElse::end")
    }
}

private struct Struct2 {
    func doSomething(context: Context) {
        var c = context
        c.logLevel = .info  // only effects from this point on
        c.logger.info("Struct2::doSomething")
        self.doSomethingElse(context: c)
        c.logger.debug("Struct2::doSomething::end")
    }

    private func doSomethingElse(context: Context) {
        var c = context
        c.logLevel = .debug  // only effects from this point on
        c.logger.info("Struct2::doSomethingElse")
        Struct3().doSomething(context: c)
        c.logger.debug("Struct2::doSomethingElse::end")
        c.logger.trace("Struct2::doSomethingElse::end::lastLine")
    }
}

private struct Struct3 {
    private let queue = DispatchQueue(label: "LocalLoggerTest::Struct3")

    func doSomething(context: Context) {
        var c = context
        c["bar"] = "baz"  // only effects from this point on
        c.logger.error("Struct3::doSomething")
        self.doSomethingElse(context: c)
        c.logger.debug("Struct3::doSomething::end")
        c.logger.trace("Struct3::doSomething::end::lastLine")
    }

    private func doSomethingElse(context: Context) {
        context.logger.error("Struct3::doSomethingElse")
        let group = DispatchGroup()
        group.enter()
        self.queue.async {
            context.logger.warning("Struct3::doSomethingElseAsync")
            let library = TestLibrary()
            library.doSomething()
            library.doSomethingAsync {
                group.leave()
            }
        }
        group.wait()
        // only effects the logger instance
        var l = context.logger
        l[metadataKey: "baz"] = "qux"
        l.debug("Struct3::doSomethingElse::Local")
        context.logger.debug("Struct3::doSomethingElse::end")
        context.logger.trace("Struct3::doSomethingElse::end::lastLine")
    }
}
