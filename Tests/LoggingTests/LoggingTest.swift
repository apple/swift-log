@testable import Logging
import XCTest

class LoggingTest: XCTestCase {
    func testAutoclosure() throws {
        // bootstrap with our test logging impl
        let logging = TestLogging()
        Logging.bootstrap(logging.make)
        var logger = Logger(label: "test")
        logger.logLevel = .info
        logger.log(level: .trace, {
            XCTFail("trace should not be called")
            return "trace"
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
        logging.history.assertNotExist(level: .trace, message: "trace")
        logging.history.assertNotExist(level: .debug, message: "debug")
        logging.history.assertExist(level: .info, message: "info")
        logging.history.assertExist(level: .warning, message: "warning")
        logging.history.assertExist(level: .error, message: "error")
    }

    func testAutoclosureWithError() throws {
        // bootstrap with our test logging impl
        let logging = TestLogging()
        Logging.bootstrap(logging.make)
        var logger = Logger(label: "test")
        logger.logLevel = .warning
        logger.trace({
            XCTFail("trace should not be called")
            return "trace"
        }(), error: TestError.boom)
        logger.debug({
            XCTFail("debug should not be called")
            return "debug"
        }(), error: TestError.boom)
        logger.info({
            XCTFail("info should not be called")
            return "info"
        }(), error: TestError.boom)
        logger.warning({
            "warning"
        }(), error: TestError.boom)
        logger.error({
            "error"
        }(), error: TestError.boom)
        XCTAssertEqual(2, logging.history.entries.count, "expected number of entries to match")
        logging.history.assertNotExist(level: .trace, message: "trace", error: TestError.boom)
        logging.history.assertNotExist(level: .debug, message: "debug", error: TestError.boom)
        logging.history.assertNotExist(level: .info, message: "info", error: TestError.boom)
        logging.history.assertExist(level: .warning, message: "warning", error: TestError.boom)
        logging.history.assertExist(level: .error, message: "error", error: TestError.boom)
    }

    func testWithError() throws {
        let logging = TestLogging()
        Logging.bootstrap(logging.make)

        let logger = Logger(label: "test")
        logger.error("oh no!", error: TestError.boom)
        logging.history.assertExist(level: .error, message: "oh no!", error: TestError.boom)
    }

    func testMultiplex() throws {
        // bootstrap with our test logging impl
        let logging1 = TestLogging()
        let logging2 = TestLogging()
        Logging.bootstrap({ MultiplexLogHandler([logging1.make(label: $0), logging2.make(label: $0)]) })

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

    enum TestError: Error {
        case boom
    }

    func testDictionaryMetadata() {
        let testLogging = TestLogging()
        Logging.bootstrap(testLogging.make)
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
        Logging.bootstrap(testLogging.make)
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
    internal class LazyMetadataBox: CustomStringConvertible {
        private var makeValue: (() -> String)?
        private var _value: String? = nil

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

        var hasRendered: Bool {
            return value != nil
        }

        public var description: String {
            return "\(self.value)"
        }
    }

    func testStringConvertibleMetadata() {
        let testLogging = TestLogging()
        Logging.bootstrap(testLogging.make)
        var logger = Logging.make("\(#function)")
        logger[metadataKey: "foo"] = .stringConvertible("raw-string")
        let lazyBox = LazyMetadataBox({ "rendered-at-first-use" })
        logger[metadataKey: "lazy"] = .stringConvertible(lazyBox)
        logger.info("hello world!")
        XCTAssertTrue(lazyBox.hasRendered)
        testLogging.history.assertExist(level: .info,
                                        message: "hello world!",
                                        metadata: ["foo": .stringConvertible("raw-string"),
                                                   "lazy": .stringConvertible(LazyMetadataBox({ "rendered-at-first-use" }))])
    }

    private func dontEvaluateThisString(file: StaticString = #file, line: UInt = #line) -> String {
        XCTFail("should not have been evaluated", file: file, line: line)
        return "should not have been evaluated"
    }

    func testAutoClosuresAreNotForcedUnlessNeeded() {
        let testLogging = TestLogging()
        Logging.bootstrap(testLogging.make)
        var logger = Logger(label: "\(#function)")
        logger.logLevel = .error

        logger.debug(self.dontEvaluateThisString(), metadata: ["foo": "\(self.dontEvaluateThisString())"])
        logger.trace(self.dontEvaluateThisString())
        logger.info(self.dontEvaluateThisString())
        logger.warning(self.dontEvaluateThisString())
        logger.log(level: .warning, self.dontEvaluateThisString())
    }

    func testLocalMetadata() {
        let testLogging = TestLogging()
        Logging.bootstrap(testLogging.make)
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
}
