# SLG-0002: In memory log handler

An in-memory handler to aid testing.

## Overview

- Proposal: SLG-0002
- Author(s): [Hamzah Malik](https://github.com/hamzahrmalik)
- Status: **Awaiting Review**
- Issue: [apple/swift-log#1](https://github.com/apple/swift-log/pull/390)
- Implementation:
    - [apple/swift-log#1](https://github.com/apple/swift-log/pull/390)
- Related links:
    - [Lightweight proposals process description](https://github.com/apple/swift-log/blob/main/Sources/Logging/Docs.docc/Proposals/Proposals.md)

### Introduction

Add an InMemoryLogHandler

### Motivation

Library maintainers should be able to test that their libraries log what they expect

### Proposed solution

Create a new InMemoryLogging product, which contains an InMemoryLogHandler

This log handler can be used to make a logger, pass the logger into some function, and then assert that logs were emitted.

### Example Usage

```swift
let logHandler = InMemoryLogHandler()
let logger = Logger(
    label: "MyApp",
    factory: { _ in
        logHandler
    }
)

// Do something with logger
someFunction(logger: logger)

// Extract logged entries
let entries = logHandler.entries       
```

### Detailed design

The proposal is to add a single new type, `InMemoryLogHandler`, which looks like:

public struct InMemoryLogHandler : LogHandler {

    public var metadata: Logger.Metadata

    public var metadataProvider: Logger.MetadataProvider?

    public var logLevel: Logger.Level

    /// A single item which was logged.
    public struct Entry : Sendable, Equatable {

        /// The level we logged at.
        public var level: Logger.Level

        /// The message which was logged.
        public var message: Logger.Message

        /// The metadata which was logged.
        public var metadata: Logger.Metadata

        public init(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata)
    }

    /// Create a new ``InMemoryLogHandler``.
    public init()

    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt)

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? { get set }

    /// All logs that have been collected.
    public var entries: [Entry] { get }

    /// Clear all entries.
    public func clear()
}

### API stability

This is purely additive. A new product is created, with a new type within it.

### Future directions

We could in future add convenience functions. For example

- a function to assert that a particular log message was logged
- a static function to create a logger with this handler

### Alternatives considered

- Creating something specifically geared towards testing. For example, providing functions to do assertions on the logs with features such as wildcarding and predicates. However, this would complicate
  the API, and it is preferable to create the minimal feature first, and then iterate on it. Furthermore, this log handler can be useful beyond testing, for example, for buffering before actually
  logging.
