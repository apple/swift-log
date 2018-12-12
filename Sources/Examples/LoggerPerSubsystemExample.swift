import Foundation
import Logging

private class Client {
    private let logger: Logger

    init(uuid: UUID, logLevel: LogLevel = .info) {
        var logger = Logging.make("com.example.TestApp.LoggerPerSubsystemExample.Client")
        // NOTE: the log level change below will only affect this `Client` instance which might or might not be what you want.
        logger.logLevel = logLevel
        logger[metadataKey: "UUID"] = uuid.description
        self.logger = logger
    }

    func spawnFreshClient() {
        self.logger.info("we're up and running")
        let otherSubSystem = OtherSubSystem()
        otherSubSystem.randomFunction()
        logger.debug("random function returned")
    }
}

private class OtherSubSystem {
    private let logger = Logging.make("com.example.TestApp.LoggerPerSubsystemExample.OtherSubSystem")

    func randomFunction() {
        // NOTE: this won't log the UUID as `Client` can't propagate its state to other sub-systems...
        self.logger.info("just to say hi")
    }
}

enum LoggerPerSubsystemExample {
    static func main() {
        Logging.bootstrap(ExampleLoggerImplementation.init)
        let logger = Logging.make("com.example.TestApp.LoggerPerSubsystemExample.main")

        logger.info("main start")
        for clientID in 0 ..< 10 {
            let client: Client
            if clientID % 3 == 0 {
                client = Client(uuid: UUID(), logLevel: .debug)
            } else {
                client = Client(uuid: UUID())
            }
            client.spawnFreshClient()
        }
        logger.info("main end")
    }
}
