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

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let levelString = level.rawValue.uppercased()

        // Merge handler metadata with message metadata
        let combinedMetadata = Self.prepareMetadata(
            base: self.metadata
            explicit: metadata
        )

        // Format metadata
        let metadataString = combinedMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ",")

        // Create log line and print to console
        let logLine = "\(label) \(timestamp) \(levelString) [\(metadataString)]: \(message)"
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

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let levelString = level.rawValue.uppercased()

        // Get provider metadata
        let providerMetadata = metadataProvider?.get() ?? [:]

        // Merge handler metadata with message metadata
        let combinedMetadata = Self.prepareMetadata(
            base: self.metadata,
            provider: self.metadataProvider,
            explicit: metadata
        )

        // Format metadata
        let metadataString = combinedMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ",")

        // Create log line and print to console
        let logLine = "\(label) \(timestamp) \(levelString) [\(metadataString)]: \(message)"
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

Attributed metadata extends the standard metadata system by allowing metadata values to carry additional attributes beyond just the value itself. This enables features like privacy labels, or any other metadata-level annotations your logging system needs.

To adopt attributed metadata in your log handler:

**1. Implement the attributed metadata log method**:

```swift
public func log(
    level: Logger.Level,
    message: Logger.Message,
    attributedMetadata: Logger.AttributedMetadata?,
    source: String,
    file: String,
    function: String,
    line: UInt
) {
    // Merge handler metadata, provider metadata, and explicit attributed metadata
    var merged = Logger.AttributedMetadata()

    // Add handler metadata with default attributes (e.g., public privacy)
    for (key, value) in self.metadata {
        merged[key] = Logger.AttributedMetadataValue(value, privacy: .public)
    }

    // Add metadata provider values with default attributes
    if let provider = self.metadataProvider {
        for (key, value) in provider.get() {
            merged[key] = Logger.AttributedMetadataValue(value, privacy: .public)
        }
    }

    // Merge with explicit attributed metadata (takes precedence)
    if let attributedMetadata = attributedMetadata {
        for (key, value) in attributedMetadata {
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

- **Default implementation**: If you don't implement the attributed metadata method, the default implementation processes attributes according to their semantics (e.g., redacting private metadata) and passes the result to the plain `log(level:message:metadata:...)` method.

- **Backward compatibility**: Implementing attributed metadata support is optional. Your handler can continue working with plain metadata only if attributed metadata features aren't needed.

##### Privacy level attribute

The `privacy` attribute allows applications to mark metadata as sensitive (`.private`) or safe to log (`.public`). This enables privacy-aware logging where handlers can redact, encrypt, or otherwise protect sensitive data.

To support privacy levels in your handler:

**1. Configure how private metadata should be handled**:

```swift
public struct MyLogHandler: LogHandler {
    public enum PrivacyBehavior {
        case log     // Log all metadata including private
        case redact  // Redact private metadata
    }

    public var privacyBehavior: PrivacyBehavior = .redact
    // ... other properties
}
```

**2. Process metadata based on privacy level**:

```swift
public func log(
    level: Logger.Level,
    message: Logger.Message,
    attributedMetadata: Logger.AttributedMetadata?,
    source: String,
    file: String,
    function: String,
    line: UInt
) {
    // Merge as shown above...

    // Process based on privacy level
    let processedMetadata = merged.compactMapValues { attributed in
        switch (attributed.attributes.privacy, self.privacyBehavior) {
        case (.public, _):
            return attributed.value  // Always log public values
        case (.private, .log):
            return attributed.value  // Log private when configured
        case (.private, .redact):
            return .string("***")    // Redact private values
        }
    }

    // Send processedMetadata to your logging backend
}
```

**Privacy-aware backend integration:**

If your logging backend has native privacy features (field-level encryption, PII scrubbing), you can use the privacy level to configure backend behavior instead of redacting locally:

```swift
for (key, attributed) in merged {
    switch attributed.attributes.privacy {
    case .public:
        sendField(key, attributed.value, encrypted: false)
    case .private:
        sendField(key, attributed.value, encrypted: true)
    }
}
```

**Complete example:**

```swift
public struct PrivacyAwareLogHandler: LogHandler {
    public enum PrivacyBehavior {
        case log     // Log all metadata including private
        case redact  // Redact private metadata
    }

    private let label: String
    public var logLevel: Logger.Level = .info
    public var metadata: Logger.Metadata = [:]
    public var metadataProvider: Logger.MetadataProvider?
    public var attributedMetadata = Logger.AttributedMetadata()
    public var privacyBehavior: PrivacyBehavior = .redact

    public init(label: String) {
        self.label = label
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.metadata[key] }
        set { self.metadata[key] = newValue }
    }

    public subscript(attributedMetadataKey key: String) -> Logger.AttributedMetadataValue? {
        get { self.attributedMetadata[key] }
        set { self.attributedMetadata[key] = newValue }
    }

    // Plain metadata logging (backward compatible)
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let output = formatLog(level: level, message: message, metadata: metadata)
        print(output)
    }

    // Attributed metadata logging with privacy support
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        attributedMetadata: Logger.AttributedMetadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        var merged = Logger.AttributedMetadata()

        // Add handler's attributed metadata
        for (key, value) in self.attributedMetadata {
            merged[key] = value
        }

        // Merge with explicit attributed metadata (takes precedence)
        if let attributedMetadata = attributedMetadata {
            for (key, value) in attributedMetadata {
                merged[key] = value
            }
        }

        // Process based on privacy level
        let processedMetadata = merged.compactMapValues { attributed -> Logger.Metadata.Value? in
            switch (attributed.attributes.privacy, self.privacyBehavior) {
            case (.public, _):
                return attributed.value
            case (.private, .log):
                return attributed.value
            case (.private, .redact):
                return .string("***")
            }
        }

        let output = formatLog(level: level, message: message, metadata: processedMetadata)
        print(output)
    }

    private func formatLog(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?
    ) -> String {
        let metadataString = metadata?.map { "\($0.key)=\($0.value)" }.joined(separator: " ") ?? ""
        return "\(label) \(level): \(message) \(metadataString)"
    }
}
```

### Performance considerations

1. **Avoid blocking**: Don't block the calling thread for I/O operations.
2. **Lazy evaluation**: Remember that messages and metadata are autoclosures.
3. **Memory efficiency**: Don't hold onto large amounts of messages.

## See Also

- ``LogHandler``
- ``StreamLogHandler``
- ``MultiplexLogHandler``
