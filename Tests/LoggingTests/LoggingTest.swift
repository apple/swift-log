@testable import Logging
import XCTest

class LoggingTest: XCTestCase {
    func testMUX() throws {
        // bootstrap with our test logging impl
        let logging1 = TestLogging()
        let logging2 = TestLogging()
        Logging.bootstrap(MultiplexLogging([logging1.make, logging2.make]).make)

        var logger = Logging.make("test")
        logger.logLevel = .warning
        logger.info("hello world")
        logger[metadataKey: "foo"] = "bar"
        logger.warning("hello world!")
        logging1.history.assertNotExist(level: .info, metadata: nil, message: "hello world")
        logging2.history.assertNotExist(level: .info, metadata: nil, message: "hello world")
        logging1.history.assertExist(level: .warning, metadata: ["foo": "bar"], message: "hello world!")
        logging2.history.assertExist(level: .warning, metadata: ["foo": "bar"], message: "hello world!")
    }

    func testDictionaryMetadata() {
        let testLogging = TestLogging()
        Logging.bootstrap(testLogging.make)
        var logger = Logging.make("\(#function)")
        logger[metadataKey: "foo"] = ["bar": "buz"]
        logger[metadataKey: "empty-dict"] = [:]
        logger[metadataKey: "nested-dict"] = ["l1key": ["l2key": ["l3key": "l3value"]]]
        logger.info("hello world!")
        testLogging.history.assertExist(level: .info,
                                        metadata: ["foo": ["bar": "buz"],
                                                   "empty-dict": [:],
                                                   "nested-dict": ["l1key": ["l2key": ["l3key": "l3value"]]]],
                                        message: "hello world!")
    }

    func testListMetadata() {
        let testLogging = TestLogging()
        Logging.bootstrap(testLogging.make)
        var logger = Logging.make("\(#function)")
        logger[metadataKey: "foo"] = ["bar", "buz"]
        logger[metadataKey: "empty-list"] = []
        logger[metadataKey: "nested-list"] = ["l1str", ["l2str1", "l2str2"]]
        logger.info("hello world!")
        testLogging.history.assertExist(level: .info,
                                        metadata: ["foo": ["bar", "buz"],
                                                   "empty-list": [],
                                                   "nested-list": ["l1str", ["l2str1", "l2str2"]]],
                                        message: "hello world!")
    }

    func testLazyMetadata() {
        let testLogging = TestLogging()
        Logging.bootstrap(testLogging.make)
        var logger = Logging.make("\(#function)")
        logger[metadataKey: "lazy-str"] = .lazy({ "foo" })
        logger[metadataKey: "lazy-list"] = .lazy({ [ .lazy({ "bar" }) ] })
        logger[metadataKey: "lazy-dict"] = .lazy({ [ "buz": .lazy({"qux"})] })
        logger.info("hello world!")
        testLogging.history.assertExist(level: .info,
                                        metadata: ["lazy-str": "foo",
                                                   "lazy-list": ["bar"],
                                                   "lazy-dict": ["buz": "qux"]],
                                        message: "hello world!")
    }

    private func dontEvaluateThisString(file: StaticString = #file, line: UInt = #line) -> String {
        XCTFail("should not have been evaluated", file: file, line: line)
        return "should not have been evaluated"
    }

    func testAutoClosuresAreNotForcedUnlessNeeded() {
        let testLogging = TestLogging()
        Logging.bootstrap(testLogging.make)
        var logger = Logging.make("\(#function)")
        logger.logLevel = .error
        logger[metadataKey: "foo"] = .lazy({"\(self.dontEvaluateThisString())"})

        logger.debug(dontEvaluateThisString())
        logger.trace(dontEvaluateThisString())
        logger.info(dontEvaluateThisString())
        logger.warning(dontEvaluateThisString())
        logger.log(level: .warning, message: dontEvaluateThisString())
    }

}
