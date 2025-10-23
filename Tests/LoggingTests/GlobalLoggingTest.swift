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

/// This is the only test suite allowed to use global LoggingSystem bootstrapping,
/// tests in the suite are executed one by one
@Suite(.serialized)
struct GlobalLoggerTest {
    @Test func traceAndAbove() throws {
        // bootstrap with our test logging impl
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal { logging.make(label: $0) }

        // change test logging config to log trace and above
        logging.config.set(value: Logger.Level.trace)
        // run our program
        Struct1().doSomething()
        // test results
        logging.history.assertExist(level: .debug, message: "Struct1::doSomething")
        logging.history.assertExist(level: .debug, message: "Struct1::doSomethingElse")
        logging.history.assertExist(level: .info, message: "Struct2::doSomething")
        logging.history.assertExist(level: .info, message: "Struct2::doSomethingElse")
        logging.history.assertExist(level: .error, message: "Struct3::doSomething")
        logging.history.assertExist(level: .error, message: "Struct3::doSomethingElse", metadata: ["foo": "bar"])
        logging.history.assertExist(level: .warning, message: "Struct3::doSomethingElseAsync", metadata: ["foo": "bar"])
        logging.history.assertExist(level: .info, message: "TestLibrary::doSomething", metadata: ["foo": "bar"])
        logging.history.assertExist(level: .info, message: "TestLibrary::doSomethingAsync", metadata: ["foo": "bar"])
        logging.history.assertExist(level: .debug, message: "Struct3::doSomethingElse::Local", metadata: ["baz": "qux"])
        logging.history.assertExist(level: .debug, message: "Struct3::doSomethingElse::end")
        logging.history.assertExist(level: .debug, message: "Struct3::doSomething::end")
        logging.history.assertExist(level: .trace, message: "Struct3::doSomething::end::lastLine")
        logging.history.assertExist(level: .debug, message: "Struct2::doSomethingElse::end")
        logging.history.assertExist(level: .trace, message: "Struct2::doSomethingElse::end::lastLine")
        logging.history.assertExist(level: .debug, message: "Struct1::doSomethingElse::end")
        logging.history.assertExist(level: .debug, message: "Struct1::doSomething::end")
        logging.history.assertExist(level: .trace, message: "Struct1::doSomething::end::lastLine")

    }

    @Test func errorAndAbove() throws {
        // bootstrap with our test logging impl
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal { logging.make(label: $0) }

        // change test logging config to log errors and above
        logging.config.set(value: Logger.Level.error)
        // run our program
        Struct1().doSomething()
        // test results
        logging.history.assertNotExist(level: .debug, message: "Struct1::doSomething")
        logging.history.assertNotExist(level: .debug, message: "Struct1::doSomethingElse")
        logging.history.assertNotExist(level: .info, message: "Struct2::doSomething")
        logging.history.assertNotExist(level: .info, message: "Struct2::doSomethingElse")
        logging.history.assertExist(level: .error, message: "Struct3::doSomething")
        logging.history.assertExist(level: .error, message: "Struct3::doSomethingElse", metadata: ["foo": "bar"])
        logging.history.assertNotExist(
            level: .warning,
            message: "Struct3::doSomethingElseAsync",
            metadata: ["foo": "bar"]
        )
        logging.history.assertNotExist(level: .info, message: "TestLibrary::doSomething", metadata: ["foo": "bar"])
        logging.history.assertNotExist(level: .info, message: "TestLibrary::doSomethingAsync", metadata: ["foo": "bar"])
        logging.history.assertNotExist(
            level: .debug,
            message: "Struct3::doSomethingElse::Local",
            metadata: ["baz": "qux"]
        )
        logging.history.assertNotExist(level: .debug, message: "Struct3::doSomethingElse::end")
        logging.history.assertNotExist(level: .debug, message: "Struct3::doSomething::end")
        logging.history.assertNotExist(level: .trace, message: "Struct3::doSomething::end::lastLine")
        logging.history.assertNotExist(level: .debug, message: "Struct2::doSomethingElse::end")
        logging.history.assertNotExist(level: .trace, message: "Struct2::doSomethingElse::end::lastLine")
        logging.history.assertNotExist(level: .debug, message: "Struct1::doSomethingElse::end")
        logging.history.assertNotExist(level: .debug, message: "Struct1::doSomething::end")
        logging.history.assertNotExist(level: .trace, message: "Struct1::doSomething::end::lastLine")
    }

    @Test func warningAndAbove() throws {
        // bootstrap with our test logging impl
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal { logging.make(label: $0) }

        // change test logging config
        logging.config.set(value: .warning)
        logging.config.set(key: "GlobalLoggerTest::Struct2", value: .info)
        logging.config.set(key: "TestLibrary", value: .debug)
        // run our program
        Struct1().doSomething()
        // test results
        logging.history.assertNotExist(level: .debug, message: "Struct1::doSomething")
        logging.history.assertNotExist(level: .debug, message: "Struct1::doSomethingElse")
        logging.history.assertExist(level: .info, message: "Struct2::doSomething")
        logging.history.assertExist(level: .info, message: "Struct2::doSomethingElse")
        logging.history.assertExist(level: .error, message: "Struct3::doSomething")
        logging.history.assertExist(level: .error, message: "Struct3::doSomethingElse", metadata: ["foo": "bar"])
        logging.history.assertExist(level: .warning, message: "Struct3::doSomethingElseAsync", metadata: ["foo": "bar"])
        logging.history.assertExist(level: .info, message: "TestLibrary::doSomething", metadata: ["foo": "bar"])
        logging.history.assertExist(level: .info, message: "TestLibrary::doSomethingAsync", metadata: ["foo": "bar"])
        logging.history.assertNotExist(
            level: .debug,
            message: "Struct3::doSomethingElse::Local",
            metadata: ["baz": "qux"]
        )
        logging.history.assertNotExist(level: .debug, message: "Struct3::doSomethingElse::end")
        logging.history.assertNotExist(level: .debug, message: "Struct3::doSomething::end")
        logging.history.assertNotExist(level: .debug, message: "Struct2::doSomethingElse::end")
        logging.history.assertNotExist(level: .debug, message: "Struct1::doSomethingElse::end")
        logging.history.assertNotExist(level: .debug, message: "Struct1::doSomething::end")
    }
}

/// MetadataProvider tests relying on the global state
extension GlobalLoggerTest {
    @Test func loggingMergesOneOffMetadataWithProvidedMetadataFromExplicitlyPassed() throws {
        let logging = TestLogging()

        LoggingSystem.bootstrapInternal(
            { logging.makeWithMetadataProvider(label: $0, metadataProvider: $1) },
            metadataProvider: .init {
                ["common": "initial"]
            }
        )

        let logger = Logger(
            label: #function,
            metadataProvider: .init {
                [
                    "common": "provider",
                    "provider": "42",
                ]
            }
        )

        logger.log(level: .info, "test", metadata: ["one-off": "42", "common": "one-off"])

        logging.history.assertExist(
            level: .info,
            message: "test",
            metadata: ["common": "one-off", "one-off": "42", "provider": "42"]
        )
    }

    @Test func loggerWithoutFactoryOverrideDefaultsToUsingLoggingSystemMetadataProvider() {
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal(
            { logging.makeWithMetadataProvider(label: $0, metadataProvider: $1) },
            metadataProvider: .init { ["provider": "42"] }
        )

        let logger = Logger(label: #function)

        logger.log(level: .info, "test", metadata: ["one-off": "42"])

        logging.history.assertExist(
            level: .info,
            message: "test",
            metadata: ["provider": "42", "one-off": "42"]
        )
    }

    @Test func loggerWithPredefinedLibraryMetadataProvider() {
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal(
            { logging.makeWithMetadataProvider(label: $0, metadataProvider: $1) },
            metadataProvider: .exampleProvider
        )

        let logger = Logger(label: #function)

        logger.log(level: .info, "test", metadata: ["one-off": "42"])

        logging.history.assertExist(
            level: .info,
            message: "test",
            metadata: ["example": "example-value", "one-off": "42"]
        )
    }

    @Test func loggerWithFactoryOverrideDefaultsToUsingLoggingSystemMetadataProvider() {
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal(
            { logging.makeWithMetadataProvider(label: $0, metadataProvider: $1) },
            metadataProvider: .init { ["provider": "42"] }
        )

        let logger = Logger(
            label: #function,
            factory: { label in
                logging.makeWithMetadataProvider(label: label, metadataProvider: LoggingSystem.metadataProvider)
            }
        )
        logger.log(level: .info, "test", metadata: ["one-off": "42"])

        logging.history.assertExist(
            level: .info,
            message: "test",
            metadata: ["provider": "42", "one-off": "42"]
        )
    }
}

private struct Struct1 {
    private let logger = Logger(label: "GlobalLoggerTest::Struct1")

    func doSomething() {
        self.logger.debug("Struct1::doSomething")
        self.doSomethingElse()
        self.logger.debug("Struct1::doSomething::end")
    }

    private func doSomethingElse() {
        self.logger.debug("Struct1::doSomethingElse")
        Struct2().doSomething()
        self.logger.debug("Struct1::doSomethingElse::end")
        self.logger.trace("Struct1::doSomething::end::lastLine")
    }
}

private struct Struct2 {
    let logger = Logger(label: "GlobalLoggerTest::Struct2")

    func doSomething() {
        self.logger.info("Struct2::doSomething")
        self.doSomethingElse()
        self.logger.debug("Struct2::doSomething::end")
    }

    private func doSomethingElse() {
        self.logger.info("Struct2::doSomethingElse")
        Struct3().doSomething()
        self.logger.debug("Struct2::doSomethingElse::end")
        self.logger.trace("Struct2::doSomethingElse::end::lastLine")
    }
}

private struct Struct3 {
    private let logger = Logger(label: "GlobalLoggerTest::Struct3")
    private let queue = DispatchQueue(label: "GlobalLoggerTest::Struct3")

    func doSomething() {
        self.logger.error("Struct3::doSomething")
        self.doSomethingElse()
        self.logger.debug("Struct3::doSomething::end")
        self.logger.trace("Struct3::doSomething::end::lastLine")
    }

    private func doSomethingElse() {
        MDC.global["foo"] = "bar"
        self.logger.error("Struct3::doSomethingElse")
        let group = DispatchGroup()
        group.enter()
        let loggingMetadata = MDC.global.metadata
        self.queue.async {
            MDC.global.with(metadata: loggingMetadata) {
                self.logger.warning("Struct3::doSomethingElseAsync")
                let library = TestLibrary()
                library.doSomething()
                library.doSomethingAsync {
                    group.leave()
                }
            }
        }
        group.wait()
        MDC.global["foo"] = nil
        // only effects the logger instance
        var l = self.logger
        l[metadataKey: "baz"] = "qux"
        l.debug("Struct3::doSomethingElse::Local")
        self.logger.debug("Struct3::doSomethingElse::end")
    }
}
