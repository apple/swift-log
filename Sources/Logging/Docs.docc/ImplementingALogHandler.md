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

#### Adopting attributed metadata in LogHandlers

Attributed metadata extends the standard metadata system by allowing metadata values to carry additional attributes beyond just the value itself.
This enables features like metadata annotations your logging system needs.

To adopt attributed metadata in your log handler:

**1. Implement the attributed metadata log method**:

```swift
public func log(event: LogEvent) {
    // Merge handler metadata, provider metadata, and explicit attributed metadata
    var merged = Logger.AttributedMetadata()

    // Add handler metadata with default attributes
    for (key, value) in self.metadata {
        merged[key] = Logger.AttributedMetadataValue(value, attributes: .init())
    }

    // Add metadata provider values (attributed providers preserve attributes)
    if let provider = self.metadataProvider {
        let providerMetadata = provider.getAttributedMetadata()
        for (key, value) in providerMetadata {
            merged[key] = value
        }
    }

    // Merge with event's attributed metadata (takes precedence)
    if let eventAttributed = event.attributedMetadata {
        for (key, value) in eventAttributed {
            merged[key] = value
        }
    }

    // Access attributes and values:
    for (key, attributedValue) in merged {
        let value = attributedValue.value              // The actual metadata value
        let attributes = attributedValue.attributes    // The attributes

        // Process based on your handler's needs
        // See attribute-specific sections below for examples
    }
}
```

**2. Provide attributed metadata storage** (optional but recommended):

```swift
public struct MyLogHandler: LogHandler {
    public var attributedMetadata = Logger.AttributedMetadata()

    public subscript(attributedMetadataKey key: String) -> Logger.AttributedMetadataValue? {
        get { self.attributedMetadata[key] }
        set { self.attributedMetadata[key] = newValue }
    }
}
```

**Key considerations:**

- **Handler metadata merging**: Your handler is responsible for merging its own `metadata` property, `metadataProvider` output, and the explicit `attributedMetadata` parameter. This is consistent with how plain metadata logging works. Explicit attributed metadata should take precedence.

- **Default attributes**: When converting plain metadata (from `self.metadata` or `metadataProvider`) to attributed metadata, assign default attribute values appropriate for your handler. For example, treat handler metadata as public for privacy purposes.

- **Default implementation**: If you don't implement the attributed metadata method, the default implementation strips attributes and passes the result to the plain `log(level:message:metadata:...)` method.

- **Backward compatibility**: Implementing attributed metadata support is optional. Your handler can continue working with plain metadata only if attributed metadata features aren't needed.

- **Performance**: Handlers that support attributed metadata should store `attributedMetadata` as their canonical metadata representation (as shown above) rather than relying on the default `LogHandler` extension that bridges between `metadata` and `attributedMetadata` via `mapValues`. The default bridge allocates a new dictionary on every property access. Similarly, reading `event.attributedMetadata` is zero-cost when the event was created with `attributedMetadata:`, while reading `event.metadata` on an attributed event incurs one dictionary allocation for the conversion.

### Performance considerations

1. **Avoid blocking**: Don't block the calling thread for I/O operations.
2. **Lazy evaluation**: Remember that messages and metadata are autoclosures.
3. **Memory efficiency**: Don't hold onto large amounts of messages.

## See Also

- ``LogHandler``
- ``StreamLogHandler``
- ``MultiplexLogHandler``
