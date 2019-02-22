//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER USAGE LOOKS LIKE
//

import ExampleImplementation
import Foundation
@testable import Logging // need access to internal bootstrap function

enum ConfigExample {
    static func main() {
        // boostrap with our config based sample implementations
        let config = Config(defaultLogLevel: .info)
        LoggingSystem.bootstrapInternal({ ConfigLogHandler(label: $0, config: config) })
        
        // run the example
        let logger = Logger(label: "com.example.TestApp")
        logger.trace("hello world?")
        // changes the config in runtime, real implemnetations will use config files instead of in-memory config
        config.set(key: "com.example.TestApp", value: .trace)
        logger.trace("hello world!")
    }
}
