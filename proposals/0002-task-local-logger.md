# Task local logger

Authors: [Franz Busch](https://github.com/FranzBusch)

## Introduction

Swift Structured Concurrency provides first class capabilities to propagate data
down the task tree via task locals. This provides an amazing opportunity for
structured logging.

## Motivation

Structured logging is a powerful tool to build logging message that contain
contextual metadata. This metadata is often build up over time by adding more to
it the more context is available. A common example for this are request ids.
Once a request id is extracted it is added to the loggers metadata and from that
point onwards all log messages contain the request id. This improves
observability and debuggability. The current pattern to do this in `swift-log`
looks like this:

```swift
func handleRequest(_ request: Request, logger: Logger) async throws {
    // Extract the request id to the metadata of the logger
    var logger = logger
    logger[metadataKey: "request.id"] = "\(request.id)"

    // Importantly we have to pass the new logger forward since it contains the request id
    try await sendResponse(logger: logger)
}
```

This works but it causes significant overhead due to passing of the logger
through all methods in the call stack. Furthermore, sometimes it is impossible to pass
a logger to some methods if those are protocol requirements like `init(from: Decoder)`.

Swift Structured Concurrency introduced the concept of task locals which
propagate down the structured task tree. This fits perfectly with how we expect
logging metadata to accumulate and provide more information the further down the 
task tree we get. 

## Proposed solution

I propose to add a new task local definition to `Logger`. Adding this task local
inside the `Logging` module provides the one canonical task local that all other
packages in the ecosystem can use.

```swift
extension Logger {
    /// The task local logger.
    ///
    /// It is recommended to use this logger in applications and libraries that use Swift Concurrency
    /// instead of passing around loggers manually.
    @TaskLocal
    public static var logger: Logger
}
```

The default value for this logger is going to be a `SwiftLogNoOpLogHandler()`.

Applications can then set the task local logger similar to how they currently bootstrap
the logging backend. If no library in the proccess is creating its own logger it is even possible
to not use the normal bootstrapping methods at all and fully rely on structured concurrency for
propagating the logger and its metadata.

```swift
static func main() async throws {
    let logger = Logger(label: "Logger") { StreamLogHandler.standardOutput(label: $0)}

    Logger.$logger.withValue(logger) {
        // Run your application code
        try await application.run()
    }
}
```

Places that want to log can then just access the task local and produce a log message.

```swift
Logger.logger.info("My log message")
```

Adding additional metadata to the task local logger is as easy as updating the logger
and binding the task local value again.

```swift
Logger.$logger.withValue(logger) {
    Logger.logger.info("First log")

    var logger = Logger.logger
    logger[metadataKey: "MetadataKey1"] = "Value1"
    Logger.$logger.withValue(logger) {
        Logger.logger.info("Second log")
    }

    Logger.logger.info("Third log")
}
```

Running the above code will produce the following output:

```
First log
MetadataKey1=Value1 Second log
Third log
```

## Alternatives considered

### Provide static log methods

Instead of going through the task local `Logger.logger` to emit log messages we
could add new static log methods like `Logger.log()` or `Logger.info()` that
access the task local internally. This is soemthing that we can do in the future
as an enhancement but isn't required initially.
