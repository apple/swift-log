import Foundation
import Logging

enum MUXExample {
    static func main() {
        // boostrap with logging that multiplexes to two copies of ExampleLoggerImplementation
        Logging.bootstrap(MultiplexLogging([ExampleLoggerImplementation.init, ExampleLoggerImplementation.init]).make)

        let logger = Logging.make("com.example.TestApp")
        logger.info("we should see this twice!")
    }
}
