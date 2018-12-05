@testable import ServerLoggerAPI
import XCTest

class LocalLoggerTest: XCTestCase {
    func test1() throws {
        // bootstrap with our test logging impl
        let logging = TestLogging()
        LoggerFactory.factory = logging.make
        // change test logging config to log traces and above
        logging.config.set(value: LogLevel.trace)
        // run our program
        let context = Context()
        Struct1().doSomething(context: context)
        // test results
        logging.history.assertExist(level: .trace, metadata: nil, message: "Struct1::doSomething")
        logging.history.assertExist(level: .trace, metadata: nil, message: "Struct1::doSomethingElse")
        logging.history.assertExist(level: .info, metadata: nil, message: "Struct2::doSomething")
        logging.history.assertExist(level: .info, metadata: nil, message: "Struct2::doSomethingElse")
        logging.history.assertExist(level: .error, metadata: ["bar": "baz"], message: "Struct3::doSomething")
        logging.history.assertExist(level: .error, metadata: ["bar": "baz"], message: "Struct3::doSomethingElse")
        logging.history.assertExist(level: .warn, metadata: ["bar": "baz"], message: "Struct3::doSomethingElseAsync")
        logging.history.assertExist(level: .info, metadata: nil, message: "TestLibrary::doSomething")
        logging.history.assertExist(level: .info, metadata: nil, message: "TestLibrary::doSomethingAsync")
        logging.history.assertExist(level: .trace, metadata: ["bar": "baz", "baz": "qux"], message: "Struct3::doSomethingElse::Local")
        logging.history.assertExist(level: .trace, metadata: ["bar": "baz"], message: "Struct3::doSomethingElse::end")
        logging.history.assertExist(level: .trace, metadata: ["bar": "baz"], message: "Struct3::doSomething::end")
        logging.history.assertExist(level: .trace, metadata: nil, message: "Struct2::doSomethingElse::end")
        logging.history.assertExist(level: .trace, metadata: nil, message: "Struct1::doSomethingElse::end")
        logging.history.assertExist(level: .trace, metadata: nil, message: "Struct1::doSomething::end")
    }

    func test2() throws {
        // bootstrap with our test logging impl
        let logging = TestLogging()
        LoggerFactory.factory = logging.make
        // change test logging config to log errors and above
        logging.config.set(value: LogLevel.error)
        // run our program
        let context = Context()
        Struct1().doSomething(context: context)
        // test results
        logging.history.assertNotExist(level: .trace, metadata: nil, message: "Struct1::doSomething") // global context
        logging.history.assertNotExist(level: .trace, metadata: nil, message: "Struct1::doSomethingElse") // global context
        logging.history.assertExist(level: .info, metadata: nil, message: "Struct2::doSomething") // local context
        logging.history.assertExist(level: .info, metadata: nil, message: "Struct2::doSomethingElse") // local context
        logging.history.assertExist(level: .error, metadata: ["bar": "baz"], message: "Struct3::doSomething") // local context
        logging.history.assertExist(level: .error, metadata: ["bar": "baz"], message: "Struct3::doSomethingElse") // local context
        logging.history.assertExist(level: .warn, metadata: ["bar": "baz"], message: "Struct3::doSomethingElseAsync") // local context
        logging.history.assertNotExist(level: .info, metadata: nil, message: "TestLibrary::doSomething") // global context
        logging.history.assertNotExist(level: .info, metadata: nil, message: "TestLibrary::doSomethingAsync") // global context
        logging.history.assertExist(level: .trace, metadata: ["bar": "baz", "baz": "qux"], message: "Struct3::doSomethingElse::Local") // hyper local context
        logging.history.assertExist(level: .trace, metadata: ["bar": "baz"], message: "Struct3::doSomethingElse::end") // local context
        logging.history.assertExist(level: .trace, metadata: ["bar": "baz"], message: "Struct3::doSomething::end") // local context
        logging.history.assertExist(level: .trace, metadata: nil, message: "Struct2::doSomethingElse::end") // local context
        logging.history.assertNotExist(level: .trace, metadata: nil, message: "Struct1::doSomethingElse::end") // global context
        logging.history.assertNotExist(level: .trace, metadata: nil, message: "Struct1::doSomething::end") // global context
    }
}

//  systems that follow the context pattern  need to implement something like this
private struct Context {
    var logger = LoggerFactory.make(identifier: "LocalLoggerTest::ContextLogger")

    // since logger is a value type, we can reuse our copy to manage logLevel
    var logLevel: LogLevel {
        get { return self.logger.logLevel }
        set { self.logger.logLevel = newValue }
    }

    // since logger is a value type, we can reuse our copy to manage metadata
    subscript(diagnosticKey: String) -> String? {
        get { return self.logger[diagnosticKey: diagnosticKey] }
        set { self.logger[diagnosticKey: diagnosticKey] = newValue }
    }
}

private struct Struct1 {
    func doSomething(context: Context) {
        context.logger.trace("Struct1::doSomething")
        self.doSomethingElse(context: context)
        context.logger.trace("Struct1::doSomething::end")
    }

    private func doSomethingElse(context: Context) {
        context.logger.trace("Struct1::doSomethingElse")
        Struct2().doSomething(context: context)
        context.logger.trace("Struct1::doSomethingElse::end")
    }
}

private struct Struct2 {
    func doSomething(context: Context) {
        var c = context
        c.logLevel = .info // only effects from this point on
        c.logger.info("Struct2::doSomething")
        doSomethingElse(context: c)
        c.logger.trace("Struct2::doSomething::end")
    }

    private func doSomethingElse(context: Context) {
        var c = context
        c.logLevel = .trace // only effects from this point on
        c.logger.info("Struct2::doSomethingElse")
        Struct3().doSomething(context: c)
        c.logger.trace("Struct2::doSomethingElse::end")
    }
}

private struct Struct3 {
    private let queue = DispatchQueue(label: "LocalLoggerTest::Struct3")

    func doSomething(context: Context) {
        var c = context
        c["bar"] = "baz" // only effects from this point on
        c.logger.error("Struct3::doSomething")
        doSomethingElse(context: c)
        c.logger.trace("Struct3::doSomething::end")
    }

    private func doSomethingElse(context: Context) {
        context.logger.error("Struct3::doSomethingElse")
        let group = DispatchGroup()
        group.enter()
        queue.async {
            context.logger.warn("Struct3::doSomethingElseAsync")
            let library = TestLibrary()
            library.doSomething()
            library.doSomethingAsync {
                group.leave()
            }
        }
        group.wait()
        // only effects the logger instance
        var l = context.logger
        l[diagnosticKey: "baz"] = "qux"
        l.trace("Struct3::doSomethingElse::Local")
        context.logger.trace("Struct3::doSomethingElse::end")
    }
}
