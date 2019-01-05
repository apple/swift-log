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
}
