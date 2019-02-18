//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER USAGE LOOKS LIKE
//

import ExampleImplementation
import Foundation
import Logging

enum MultiplexExample {
    static func main() {
        // boostrap with two of our sample implementations
        Logging.bootstrap({ MultiplexLogHandler([SimpleLogHandler(label: $0), FileLogHandler(label: $0)]) })
        // run the example
        let logger = Logger(label: "com.example.TestApp")
        logger.info("hello world!")
    }
}
