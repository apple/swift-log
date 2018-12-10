import Foundation
import Logging

// this model just uses one global logger. This is similar to what IBM's Logger API uses today (except that the one
// global thing has static methods.
let logger = Logging.make("com.example.TestApp.OneGlobalLoggerExample")

enum OneGlobalLoggerExample {
    static func main() {
        for _ in 0 ..< 10 {
            // NOTE: we can't change the log level per client because we only have one global logger
            self.spawnFreshClient(uuid: UUID())
        }
    }

    static func spawnFreshClient(uuid _: UUID) {
        logger.info("we're up and running")
        self.randomFunction()
    }

    static func randomFunction() {
        logger.debug("just to say hi, here the log level / UUID do not get propagated")
    }
}
