import ExampleLoggerImpl
import Foundation
import ServerLoggerAPI

enum RandomExample {
    static func main() {
        // let's first start off with whatever is the default
        print("=== default ===")
        var logger = LoggerFactory.make(identifier: "com.example.TestApp.LoggerBeforeConfig")
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

        print("=== reconfiguring the LoggerFactory's default to have a minimum level of warn with StdoutLogger ===")
        LoggerFactory.factory = { identifier in
            let logger = StdoutLogger(identifier: identifier)
            logger.logLevel = .warn
            return logger
        }
        logger = LoggerFactory.make(identifier: "com.example.TestApp.LoggerAfterConfig1")

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
        LoggerFactory.factory = ExampleLoggerImplementation.init
        logger = LoggerFactory.make(identifier: "com.example.TestApp.LoggerAfterConfig2")

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
