//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER USAGE LOOKS LIKE
//

import ExampleImplementation
import Foundation
import Logging

enum ConfigExample {
    static func main() {
        // boostrap with our config based sample implementations
        let logging = ConfigLogging()
        Logging.bootstrap(logging.make)
        // run the example
        let logger = Logging.make("com.example.TestApp")
        logger.trace("hello world?")
        // changes the config in runtime, real implemnetations will use config files instead of in-memory config
        logging.config.set(key: "com.example.TestApp", value: .trace)
        logger.trace("hello world!")
    }
}
