@testable import Logging
import XCTest

class GlobalLoggerTest: XCTestCase {
    func test1() throws {
        // bootstrap with our test logging impl
        let logging = TestLogging()
        Logger.bootstrap(logging.make)
        // change test logging config to log traces and above
        logging.config.set(value: Logger.Level.trace)
        // run our program
        Struct1().doSomething()
        // test results
        logging.history.assertExist(level: .trace, message: "Struct1::doSomething")
        logging.history.assertExist(level: .trace, message: "Struct1::doSomethingElse")
        logging.history.assertExist(level: .info, message: "Struct2::doSomething")
        logging.history.assertExist(level: .info, message: "Struct2::doSomethingElse")
        logging.history.assertExist(level: .error, message: "Struct3::doSomething")
        logging.history.assertExist(level: .error, message: "Struct3::doSomethingElse", metadata: ["foo": "bar"])
        logging.history.assertExist(level: .warning, message: "Struct3::doSomethingElseAsync", metadata: ["foo": "bar"])
        logging.history.assertExist(level: .info, message: "TestLibrary::doSomething", metadata: ["foo": "bar"])
        logging.history.assertExist(level: .info, message: "TestLibrary::doSomethingAsync", metadata: ["foo": "bar"])
        logging.history.assertExist(level: .trace, message: "Struct3::doSomethingElse::Local", metadata: ["baz": "qux"])
        logging.history.assertExist(level: .trace, message: "Struct3::doSomethingElse::end")
        logging.history.assertExist(level: .trace, message: "Struct3::doSomething::end")
        logging.history.assertExist(level: .trace, message: "Struct2::doSomethingElse::end")
        logging.history.assertExist(level: .trace, message: "Struct1::doSomethingElse::end")
        logging.history.assertExist(level: .trace, message: "Struct1::doSomething::end")
    }

    func test2() throws {
        // bootstrap with our test logging impl
        let logging = TestLogging()
        Logger.bootstrap(logging.make)
        // change test logging config to log errors and above
        logging.config.set(value: Logger.Level.error)
        // run our program
        Struct1().doSomething()
        // test results
        logging.history.assertNotExist(level: .trace, message: "Struct1::doSomething")
        logging.history.assertNotExist(level: .trace, message: "Struct1::doSomethingElse")
        logging.history.assertNotExist(level: .info, message: "Struct2::doSomething")
        logging.history.assertNotExist(level: .info, message: "Struct2::doSomethingElse")
        logging.history.assertExist(level: .error, message: "Struct3::doSomething")
        logging.history.assertExist(level: .error, message: "Struct3::doSomethingElse", metadata: ["foo": "bar"])
        logging.history.assertNotExist(level: .warning, message: "Struct3::doSomethingElseAsync", metadata: ["foo": "bar"])
        logging.history.assertNotExist(level: .info, message: "TestLibrary::doSomething", metadata: ["foo": "bar"])
        logging.history.assertNotExist(level: .info, message: "TestLibrary::doSomethingAsync", metadata: ["foo": "bar"])
        logging.history.assertNotExist(level: .trace, message: "Struct3::doSomethingElse::Local", metadata: ["baz": "qux"])
        logging.history.assertNotExist(level: .trace, message: "Struct3::doSomethingElse::end")
        logging.history.assertNotExist(level: .trace, message: "Struct3::doSomething::end")
        logging.history.assertNotExist(level: .trace, message: "Struct2::doSomethingElse::end")
        logging.history.assertNotExist(level: .trace, message: "Struct1::doSomethingElse::end")
        logging.history.assertNotExist(level: .trace, message: "Struct1::doSomething::end")
    }

    func test3() throws {
        // bootstrap with our test logging impl
        let logging = TestLogging()
        Logger.bootstrap(logging.make)
        // change test logging config
        logging.config.set(value: .warning)
        logging.config.set(key: "GlobalLoggerTest::Struct2", value: .info)
        logging.config.set(key: "TestLibrary", value: .trace)
        // run our program
        Struct1().doSomething()
        // test results
        logging.history.assertNotExist(level: .trace, message: "Struct1::doSomething")
        logging.history.assertNotExist(level: .trace, message: "Struct1::doSomethingElse")
        logging.history.assertExist(level: .info, message: "Struct2::doSomething")
        logging.history.assertExist(level: .info, message: "Struct2::doSomethingElse")
        logging.history.assertExist(level: .error, message: "Struct3::doSomething")
        logging.history.assertExist(level: .error, message: "Struct3::doSomethingElse", metadata: ["foo": "bar"])
        logging.history.assertExist(level: .warning, message: "Struct3::doSomethingElseAsync", metadata: ["foo": "bar"])
        logging.history.assertExist(level: .info, message: "TestLibrary::doSomething", metadata: ["foo": "bar"])
        logging.history.assertExist(level: .info, message: "TestLibrary::doSomethingAsync", metadata: ["foo": "bar"])
        logging.history.assertNotExist(level: .trace, message: "Struct3::doSomethingElse::Local", metadata: ["baz": "qux"])
        logging.history.assertNotExist(level: .trace, message: "Struct3::doSomethingElse::end")
        logging.history.assertNotExist(level: .trace, message: "Struct3::doSomething::end")
        logging.history.assertNotExist(level: .trace, message: "Struct2::doSomethingElse::end")
        logging.history.assertNotExist(level: .trace, message: "Struct1::doSomethingElse::end")
        logging.history.assertNotExist(level: .trace, message: "Struct1::doSomething::end")
    }
}

private struct Struct1 {
    private let logger = Logger(label: "GlobalLoggerTest::Struct1")

    func doSomething() {
        self.logger.trace("Struct1::doSomething")
        self.doSomethingElse()
        self.logger.trace("Struct1::doSomething::end")
    }

    private func doSomethingElse() {
        self.logger.trace("Struct1::doSomethingElse")
        Struct2().doSomething()
        self.logger.trace("Struct1::doSomethingElse::end")
    }
}

private struct Struct2 {
    let logger = Logger(label: "GlobalLoggerTest::Struct2")

    func doSomething() {
        self.logger.info("Struct2::doSomething")
        self.doSomethingElse()
        self.logger.trace("Struct2::doSomething::end")
    }

    private func doSomethingElse() {
        self.logger.info("Struct2::doSomethingElse")
        Struct3().doSomething()
        self.logger.trace("Struct2::doSomethingElse::end")
    }
}

private struct Struct3 {
    private let logger = Logger(label: "GlobalLoggerTest::Struct3")
    private let queue = DispatchQueue(label: "GlobalLoggerTest::Struct3")

    func doSomething() {
        self.logger.error("Struct3::doSomething")
        self.doSomethingElse()
        self.logger.trace("Struct3::doSomething::end")
    }

    private func doSomethingElse() {
        MDC.global["foo"] = "bar"
        self.logger.error("Struct3::doSomethingElse")
        let group = DispatchGroup()
        group.enter()
        let loggingMetadata = MDC.global.metadata
        queue.async {
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
        var l = logger
        l[metadataKey: "baz"] = "qux"
        l.trace("Struct3::doSomethingElse::Local")
        logger.trace("Struct3::doSomethingElse::end")
    }
}
