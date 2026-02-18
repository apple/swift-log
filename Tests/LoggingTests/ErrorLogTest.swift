import Testing

@testable import Logging

struct ErrorLogTest {
    let testLogging = TestLogging()
    let logger: Logger
    
    init() {
        let handler = testLogging.make(label: "testHandler")
        var logger = Logger(label: "testLogger", handler)
        logger.logLevel = .trace
        self.logger = logger
    }
    
    @Test(arguments: Logger.Level.allCases)
    func logWithError(level: Logger.Level) async throws {
        logger.log(level: level, "Log", error: TestError.first)
        testLogging.history.assertExist(level: level, message: "Log", metadata: ["error.message": "first", "error.type": "LoggingTests.TestError"])
    }
    
    @Test func logWarningWithError() async throws {
        logger.warning("Log", error: TestError.second("associated value"))
        testLogging.history.assertExist(level: .warning, message: "Log", metadata: ["error.message": "second(\"associated value\")", "error.type": "LoggingTests.TestError"])
    }
}

enum TestError: Error {
    case first
    case second(String)
}
