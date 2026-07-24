# Implementing a log handler

Create a custom logging backend that provides logging services for your apps and libraries.

## Overview

To become a compatible logging backend that any SwiftLog consumer can use,
you need to fulfill a few requirements, primarily conforming to the
``LogHandler`` protocol.

### Implement with value type semantics

Your log handler **must be a `struct`** and exhibit value semantics. This
ensures that changes to one logger don't affect others.

To verify that your handler reflects value semantics ensure that it passes this
test:

```swift
@Test
func logHandlerValueSemantics() {
    LoggingSystem.bootstrap(MyLogHandler.init)
    var logger1 = Logger(label: "first logger")
    logger1.logLevel = .debug
    logger1[metadataKey: "only-on"] = "first"

    var logger2 = logger1
    logger2.logLevel = .error                  // Must not affect logger1
    logger2[metadataKey: "only-on"] = "second" // Must not affect logger1

    // These expectations must pass
    #expect(logger1.logLevel == .debug)
    #expect(logger2.logLevel == .error)
    #expect(logger1[metadataKey: "only-on"] == "first")
    #expect(logger2[metadataKey: "only-on"] == "second")
}
```

> Note: In special cases, it is acceptable for a log handler to provide
> global log level overrides that may affect all log handlers created.

### Example implementation

Here's a complete example of a simple print-based log handler:

```swift
import Foundation
import Logging

public struct PrintLogHandler: LogHandler {
    private let label: String
    public var logLevel: Logger.Level = .info
    public var metadata: Logger.Metadata = [:]

    public init(label: String) {
        self.label = label
    }

    public func log(event: LogEvent) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let levelString = event.level.rawValue.uppercased()

        // Merge handler metadata with message metadata
        let combinedMetadata = Self.prepareMetadata(
            base: self.metadata,
            explicit: event.metadata
        )

        // Format metadata
        let metadataString = combinedMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ",")

        // Create log line and print to console
        let logLine = "\(label) \(timestamp) \(levelString) [\(metadataString)]: \(event.message)"
        print(logLine)
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[key]
        }
        set {
            self.metadata[key] = newValue
        }
    }

    static func prepareMetadata(
        base: Logger.Metadata,
        explicit: Logger.Metadata?
    ) -> Logger.Metadata? {
        var metadata = base

        guard let explicit else {
            // all per-log-statement values are empty
            return metadata
        }

        metadata.merge(explicit, uniquingKeysWith: { _, explicit in explicit })

        return metadata
    }
}

```

### Constructing handlers that need more than a label

Many backends need more than a `label` to build: a file path, a remote address, credentials, or
a buffer. A handler is an ordinary value that you construct, so nothing constrains its
initializer — it can take any parameters it needs, and it can `throw`. There is no
protocol-required `init(label:)`. The single `label` argument on factory methods such as
`StreamLogHandler.standardOutput(label:)` is a convention, not a requirement.

Open expensive or fallible resources — a file, a socket — **up front**, in your own `throw`ing
initializer, so failures surface at setup time. ``LogHandler/log(event:)`` cannot throw, so an
error deferred to logging time has nowhere to go. Keep the handler `struct` cheap and copyable,
and place the shared resource behind a thread-safe reference type: value semantics apply to a
handler's *configuration* — its level and metadata — not its *destination*, so copies writing to
the same file are correct and expected.

The `FileLogHandler` below opens its file once, in a `throw`ing initializer on a shared
`Destination`. The handler `struct` itself stays a cheap, copyable value:

```swift
import Foundation
import Logging
import Synchronization

/// A log handler that appends formatted log lines to a file on disk.
public struct FileLogHandler: LogHandler {
    /// The shared, thread-safe destination. Open it once, then share it across handlers: being a
    /// reference type, all those value-semantic handlers write through one locked file handle.
    public final class Destination: @unchecked Sendable {
        private let fileHandle: Mutex<FileHandle>

        /// Opens `url` for appending. All validation happens here, at setup time.
        public init(writingTo url: URL) throws {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: url.path) {
                guard fileManager.createFile(atPath: url.path, contents: nil) else {
                    throw Failure.cannotCreateFile(url)
                }
            }
            self.fileHandle = .init(try FileHandle(forWritingTo: url))
            _ = try self.fileHandle.withLock { try $0.seekToEnd() }
        }

        func write(_ line: String) {
            // `log(event:)` cannot throw, so a write failure is handled here, not propagated.
            do {
                try self.fileHandle.withLock { try $0.write(contentsOf: Data(line.utf8)) }
            } catch {
                // Surface the failure without crashing the application.
                try? FileHandle.standardError.write(contentsOf: Data("FileLogHandler: \(error)\n".utf8))
            }
        }

        /// Flushes and closes the file. Call this during shutdown.
        public func close() {
            self.fileHandle.withLock { try? $0.close() }
        }
    }

    /// Errors thrown while opening a ``Destination``.
    public enum Failure: Error {
        case cannotCreateFile(URL)
    }

    private let label: String
    private let destination: Destination

    // Per-logger configuration — this is what must carry value semantics.
    public var logLevel: Logger.Level = .info
    public var metadata: Logger.Metadata = [:]
    public var metadataProvider: Logger.MetadataProvider?

    /// Cheap and non-throwing, so it is safe to call from a bootstrap factory closure per label.
    public init(label: String, destination: Destination, metadataProvider: Logger.MetadataProvider? = nil) {
        self.label = label
        self.destination = destination
        self.metadataProvider = metadataProvider
    }

    public func log(event: LogEvent) {
        var merged = self.metadata
        if let provided = self.metadataProvider?.get() {
            merged.merge(provided, uniquingKeysWith: { _, new in new })
        }
        if let explicit = event.metadata {
            merged.merge(explicit, uniquingKeysWith: { _, new in new })
        }
        let renderedMetadata =
            merged.isEmpty
            ? ""
            : " " + merged.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        self.destination.write("\(event.level) \(self.label):\(renderedMetadata) \(event.message)\n")
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.metadata[key] }
        set { self.metadata[key] = newValue }
    }
}
```

#### Installing it

Construct the destination where you can `try`, build a logger backed by the handler, and bind it
as ``Logger/current`` for the application's lifetime with `withLogger`:

```swift
// Open the file once, where setup can throw.
let destination = try FileLogHandler.Destination(writingTo: URL(fileURLWithPath: "/var/log/myapp.log"))
defer { destination.close() }

// Build a logger backed by the handler, then bind it for the scope.
let logger = Logger(label: "app") { label in
    FileLogHandler(label: label, destination: destination)
}
try await withLogger(logger) { logger in
    logger.info("Application started")
    // Code in this scope reads the handler through Logger.current.
}
```

The `try` on `Destination` is where setup fails if the path is unwritable: validation happens
before the logger is constructed, so you never need a throwing factory overload. The same pattern
extends to handlers that reach a remote service — validate and connect up front, keep
``LogHandler/log(event:)`` non-blocking by buffering onto a background task, and provide a
`close()` or `shutdown()` (or a
[Swift Service Lifecycle](https://github.com/swift-server/swift-service-lifecycle) service) to
flush on shutdown. For runtime failures the handler cannot avoid — a full disk, a broken pipe —
degrade gracefully inside `log(event:)` by dropping, retrying, or reporting to `stderr`. Never
call `fatalError` on the logging path.

### Advanced features

#### Metadata providers

Metadata providers allow you to dynamically add contextual information to all
log messages without explicitly passing it each time. Common use cases include
request IDs, user sessions, or trace contexts that should be included in logs
throughout a request's lifecycle.

```swift
import Foundation
import Logging

public struct PrintLogHandler: LogHandler {
    private let label: String
    public var logLevel: Logger.Level = .info
    public var metadata: Logger.Metadata = [:]
    public var metadataProvider: Logger.MetadataProvider?

    public init(label: String) {
        self.label = label
    }

    public func log(event: LogEvent) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let levelString = event.level.rawValue.uppercased()

        // Merge handler metadata with message metadata
        let combinedMetadata = Self.prepareMetadata(
            base: self.metadata,
            provider: self.metadataProvider,
            explicit: event.metadata
        )

        // Format metadata
        let metadataString = combinedMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ",")

        // Create log line and print to console
        let logLine = "\(label) \(timestamp) \(levelString) [\(metadataString)]: \(event.message)"
        print(logLine)
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[key]
        }
        set {
            self.metadata[key] = newValue
        }
    }

    static func prepareMetadata(
        base: Logger.Metadata,
        provider: Logger.MetadataProvider?,
        explicit: Logger.Metadata?
    ) -> Logger.Metadata? {
        var metadata = base

        let provided = provider?.get() ?? [:]

        guard !provided.isEmpty || !((explicit ?? [:]).isEmpty) else {
            // all per-log-statement values are empty
            return metadata
        }

        if !provided.isEmpty {
            metadata.merge(provided, uniquingKeysWith: { _, provided in provided })
        }

        if let explicit = explicit, !explicit.isEmpty {
            metadata.merge(explicit, uniquingKeysWith: { _, explicit in explicit })
        }

        return metadata
    }
}
```

#### Reading metadata attributes in LogHandlers

Metadata values can carry attributes alongside their string representation. Attributes are embedded inside
`MetadataValue` via the `.stringConvertible` case and are accessible through the `value.attributes` property. This
enables features like sensitivity annotations without any changes to your handler's protocol conformance.

To read attributes in your log handler:

```swift
public func log(event: LogEvent) {
    // Merge handler metadata, provider metadata, and event metadata as usual
    var merged = self.metadata

    if let provider = self.metadataProvider {
        merged.merge(provider.get(), uniquingKeysWith: { _, rhs in rhs })
    }

    if let eventMetadata = event.metadata {
        merged.merge(eventMetadata, uniquingKeysWith: { _, rhs in rhs })
    }

    // Read attributes from individual values:
    for (key, value) in merged {
        let attributes = value.attributes    // Empty if the value carries no attributes

        // Process based on your handler's needs
        // For example, check for a custom attribute:
        // if attributes[MyAttribute.self] == .flagged { ... }
    }
}
```

**Key considerations:**

- **Opt-in inspection**: Attributes are invisible unless you call `value.attributes`. Handlers that do not care about
  attributes work without any changes.

- **No new protocol requirements**: Reading attributes does not require implementing any new `LogHandler` properties
  or subscripts. The `metadata` property and `metadataKey` subscript work exactly as before.

- **Attributes flow through metadata**: Attributed values flow naturally through metadata merging, `MetadataProvider`,
  and `MultiplexLogHandler` — no special handling needed.

### Performance considerations

1. **Avoid blocking**: Don't block the calling thread for I/O operations.
2. **Lazy evaluation**: Remember that messages and metadata are autoclosures.
3. **Memory efficiency**: Don't hold onto large amounts of messages.

## See Also

- ``LogHandler``
- ``StreamLogHandler``
- ``MultiplexLogHandler``
