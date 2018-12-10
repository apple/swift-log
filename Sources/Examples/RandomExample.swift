import Foundation
import Logging

enum RandomExample {
    static func main() {
        // let's first start off with whatever is the default
        print("=== default ===")
        var logger = Logging.make("com.example.TestApp.LoggerBeforeConfig")
        logger.trace("trace, not logged")
        logger.debug("debug, not logged")
        logger.info("default, info, no context")
        logger.warn("default, warn, no context")
        logger.error("default, error, no context")

        logger[diagnosticKey: "foo"] = "bar"
        logger[diagnosticKey: "UUID"] = UUID().description

        logger.trace("trace, not logged")
        logger.debug("debug, not logged")
        logger.info("default, info, with context")
        logger.warn("default, warn, with context")
        logger.error("default, error, with context")

        print("=== reconfiguring the Logging's default to have a minimum level of warn with StdoutLogger ===")
        Logging.bootstrap({ label in
            let logger = StdoutLogger(label: label)
            logger.logLevel = .warn
            return logger
        })
        logger = Logging.make("com.example.TestApp.LoggerAfterConfig1")

        logger.trace("trace, not logged")
        logger.debug("debug, not logged")
        logger.info("info, no context")
        logger.warn("warn, no context")
        logger.error("error, no context")

        logger[diagnosticKey: "bar"] = "buz"
        logger[diagnosticKey: "UUID"] = UUID().description

        logger.trace("trace, not logged")
        logger.debug("debug, not logged")
        logger.info("info, with context")
        logger.warn("warn, with context")
        logger.error("error, with context")

        print("=== installing a custom logger ===")
        Logging.bootstrap(ExampleLoggerImplementation.init)
        logger = Logging.make("com.example.TestApp.LoggerAfterConfig2")

        logger.trace("trace, not logged")
        logger.debug("debug, not logged")
        logger.info("info, no context")
        logger.warn("warn, no context")
        logger.error("error, no context")

        logger[diagnosticKey: "buz"] = "cux"
        logger[diagnosticKey: "UUID"] = UUID().description

        logger.trace("trace, not logged")
        logger.debug("debug, not logged")
        logger.info("info, with context")
        logger.warn("warn, with context")
        logger.error("error, with context")
    }
}
