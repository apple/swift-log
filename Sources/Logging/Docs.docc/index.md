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

Use this package if you're writing a cross-platform application (for example, Linux and
macOS) or library, and want to target this logging API.

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
2025-10-24T17:26:47-0700 info MyLogger: [your_app] Hello World!
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


## Topics

### Logging API

- <doc:UnderstandingLoggers>
- ``Logger``
- ``LoggingSystem``

### Log Handlers

- ``LogHandler``
- ``MultiplexLogHandler``
- ``StreamLogHandler``
- ``SwiftLogNoOpLogHandler``

### Best Practices

- <doc:LoggingBestPractices>
- <doc:ImplementingALogHandler>

### Contributing

- <doc:Proposals>
