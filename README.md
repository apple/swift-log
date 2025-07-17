# SwiftLog

This repository contains a logging API implementation for Swift.
SwiftLog provides a unified, performant, and ergonomic logging API that can be
adopted by libraries and applications across the Swift ecosystem.

- 📚 **Documentation** and **tutorials** are available on the [Swift Package Index](https://swiftpackageindex.com/apple/swift-log)
- 🚀 **Contributions** are welcome, please see [CONTRIBUTING.md](CONTRIBUTING.md)
- 🪪 **License** is Apache 2.0, repeated in [LICENSE.txt](LICENSE.txt)
- 🔒 **Security** issues should be reported via the process in [SECURITY.md](SECURITY.md)
- 🔀 **Available Logging Backends**: SwiftLog is an API package - you'll want to
choose from the many
[community-maintained logging backends](#available-log-handler-backends) for production use

## Quick Start

The following snippet shows how to add SwiftLog to your Swift Package:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "YourApp",
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.6.0")
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        )
    ]
)
```

Then start logging:

```swift
import Logging

// Create a logger
let logger = Logger(label: "com.example.YourApp")

// Log at different levels
logger.info("Application started")
logger.warning("This is a warning")
logger.error("Something went wrong", metadata: ["error": "\(error)"])

// Add metadata for context
var requestLogger = logger
requestLogger[metadataKey: "request-id"] = "\(UUID())"
requestLogger.info("Processing request")
```

## Available log handler backends

The community has built numerous specialized logging backends.

A great way to discover available log backend implementations is searching the
[Swift Package Index](https://swiftpackageindex.com/search?query=swift-log)
for the `swift-log` keyword.
