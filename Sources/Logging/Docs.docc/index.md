# ``Logging``

A unified, performant, and ergonomic logging API for Swift.

## Overview

SwiftLog provides a logging API package designed to establish a common API the
ecosystem can use. It allows packages to emit log messages without tying them to
any specific logging implementation, while applications can choose any
compatible logging backend.

SwiftLog is an _API package_ which cuts the logging problem in half:
1. A logging API (this package)
2. Logging backend implementations (community-provided)

This separation allows libraries to adopt the API while applications choose any
compatible logging backend implementation without requiring changes from
libraries.

## Getting Started

Use this If you are writing a cross-platform application (for example, Linux and
macOS) or library, target this logging API.

### Adding the Dependency

Add the dependency to your `Package.swift`:

```swift
.package(url: "https://github.com/apple/swift-log", from: "1.6.0")
```

And to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Logging", package: "swift-log")
    ]
)
```

### Basic Usage

```swift
// Import the logging API
import Logging

// Create a logger with a label
let logger = Logger(label: "MyLogger")

// Use it to log messages
logger.info("Hello World!")
```

This outputs:
```
2019-03-13T15:46:38+0000 info: Hello World!
```

### Default Behavior

SwiftLog provides basic console logging via ``StreamLogHandler``. By default it
uses `stdout`, however, you can configure it to use `stderr` instead:

```swift
LoggingSystem.bootstrap(StreamLogHandler.standardError)
```

``StreamLogHandler`` is primarily for convenience. For production applications,
implement the ``LogHandler`` protocol directly or use a community-maintained
backend.

## Core Concepts

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

SwiftLog supports seven log levels (from least to most severe):
- ``Logger/Level/trace``
- ``Logger/Level/debug`` 
- ``Logger/Level/info``
- ``Logger/Level/notice``
- ``Logger/Level/warning``
- ``Logger/Level/error``
- ``Logger/Level/critical``

Log levels can be changed per logger without affecting others:

```swift
var logger = Logger(label: "MyLogger")
logger.logLevel = .debug
```

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

A ``Logger`` has an immutable `label` identifying its creator, while each log
message carries a `source` parameter identifying where the message originated.
Use `source` for filtering messages from specific subsystems.


## Topics

### Logging API

- ``Logger``
- ``LoggingSystem``

### Log Handlers

- ``LogHandler``
- ``MultiplexLogHandler``
- ``StreamLogHandler``
- ``SwiftLogNoOpLogHandler``

### Best Practices

- <doc:LoggingBestPractices>
- <doc:001-ChoosingLogLevels>

