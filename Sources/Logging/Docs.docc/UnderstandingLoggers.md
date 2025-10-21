# Understanding Loggers and Log Handlers

<!--@START_MENU_TOKEN@-->Summary<!--@END_MENU_TOKEN@-->

## Overview

Creating and retrieving a logger provides an instance that you can use to log messages.
Instances of loggers have a level that you use when logging a message to indicate the importance of the message.

SwiftLog defines seven log levels, represented by ``Logger/Level``, ordered from least to
most severe:

- ``Logger/Level/trace``
- ``Logger/Level/debug``
- ``Logger/Level/info``
- ``Logger/Level/notice``
- ``Logger/Level/warning``
- ``Logger/Level/error``
- ``Logger/Level/critical``

Once sent a message is sent to a logger, it is processed by a log handler. 
A handler is configured by the app using the logger, usually for the environment in which that app runs and processing messages appropriate to that environment.
If the app doesn't provide its own log handler, swift-log defaults to use a ``StreamLogHandler`` that presents the log messages at `STDOUT`.

### Loggers

Loggers are used to emit log messages at different severity levels:

```swift
// Informational message
logger.info("Processing request")

// Something went wrong
logger.error("Houston, we have a problem")
```

``Logger`` is a value type with value semantics, meaning that when you modify a
logger's configuration (like its log level or metadata), it only affects that
specific logger instance:

```swift
let baseLogger = Logger(label: "MyApp")

// Create a new logger with different configuration.
var requestLogger = baseLogger
requestLogger.logLevel = .debug
requestLogger[metadataKey: "request-id"] = "\(UUID())"

// baseLogger is unchanged. It still has default log level and no metadata
// requestLogger has debug level and request-id metadata.
```

This value type behavior makes loggers safe to pass between functions and modify
without unexpected side effects.

### Log Levels

Log levels can be changed per logger without affecting others:

```swift
var logger = Logger(label: "MyLogger")
logger.logLevel = .debug
```

For guidance on what level to use for a message, see <doc:001-ChoosingLogLevels>.

### Logging Metadata

Metadata provides contextual information crucial for debugging:

```swift
var logger = Logger(label: "com.example.server")
logger[metadataKey: "request-uuid"] = "\(UUID())"
logger.info("Processing request")
```

Output:
```
2019-03-13T18:30:02+0000 info: request-uuid=F8633013-3DD8-481C-9256-B296E43443ED Processing request
```

### Source vs Label

A ``Logger`` has an immutable `label` that identifies its creator, while each log
message carries a `source` parameter that identifies where the message originated.
Use `source` for filtering messages from specific subsystems.
