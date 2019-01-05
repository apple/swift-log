//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER USAGE LOOKS LIKE
//

import ExampleImplementation
import Foundation
import Logging

enum MUXExample {
    static func main() {
        // boostrap with two of our sample implementations
        let logging = MultiplexLogging([SimpleLogging().make, FileLogging().make])
        Logging.bootstrap(logging.make)
        // run the example
        let logger = Logging.make("com.example.TestApp")
        logger.info("hello world!")
    }
}
