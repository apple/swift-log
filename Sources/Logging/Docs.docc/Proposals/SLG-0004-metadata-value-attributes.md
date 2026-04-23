# SLG-0004: Metadata value attributes

Add an extensible per-value attribute mechanism for metadata.

## Overview

- Proposal: SLG-0004
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **Awaiting Review**
- Issue: [apple/swift-log#204](https://github.com/apple/swift-log/issues/204)
- Implementation:
    - [apple/swift-log#439](https://github.com/apple/swift-log/pull/439)
- Related links:
    - [Lightweight proposals process description](https://github.com/apple/swift-log/blob/main/Sources/Logging/Docs.docc/Proposals/Proposals.md)
    - [First iteration of the proposal](https://forums.swift.org/t/proposal-slg-0004-metadata-values-privacy-attribute/85249)

### Introduction

Introduce an extensible mechanism for attaching per-value attributes to metadata. The core `Logging` module provides
the protocol and storage. Attribute packages define concrete attributes using the `MetadataAttributeKey` protocol.

### Motivation

Metadata values in `swift-log` are opaque strings by the time the `LogHandler` receives them. The call site often
knows things about a value that the handler cannot infer — for example, whether the value should be redacted in
different environments.

Today, there is no way to express this. A single log statement can contain values that need different treatment, and
log levels cannot help because they are per-statement, not per-value:

```swift
logger.info("Login", metadata: [
    "action": "\(action)",        // safe to log
    "user_email": "\(email)",     // should be redacted in production, but nothing tells the handler
])
```

The workaround is handler-side key-based rules (`redact: ["email", "card-*", ...]`), but this is fragile:

- Rules break when libraries rename keys.
- Rules require coordination across all dependencies.
- The rule mapping is invisible at the call site.

### Proposed solution

A new `attributedMetadata` parameter on `Logger` log methods accepts metadata values wrapped with attributes. Libraries
define attribute types conforming to `MetadataAttributeKey` and provide ergonomic string interpolation overloads.
Handlers read the attributes and act on them:

```swift
import Logging

public enum Sensitivity: Int64, Logger.MetadataAttributeKey, Sendable {
    case sensitive = 1
    case `public` = 2
}

extension Logger.AttributedMetadataValue.StringInterpolation {
    public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
        _ value: T, sensitivity: Sensitivity
    ) {
        self.appendInterpolation(value, attributes: { $0[Sensitivity.self] = sensitivity })
    }
}

logger.info("Request", attributedMetadata: [
    "method": "\(req.method)",
    "user_id": "\(req.userId, sensitivity: .sensitive)",
])
```

Handlers that support specific attributes read them from `event.attributedMetadata` and act accordingly. Handlers that
do not understand attributes ignore them or read `event.metadata`, which strips attributes and returns raw values automatically.
The existing `metadata:` parameter continues to work unchanged.

Attributes are **classifications, not enforcement**. An attribute does not guarantee any particular handler behavior —
the handler may not support it. Applications needing guaranteed behavior must enforce it at a different abstraction.

The attribute mechanism is extensible: packages define their own attribute types using `MetadataAttributeKey`.
A chained `LogHandler` can read the attributes it cares about, act on them, and forward the rest to the next handler
in the chain — enabling composable handler pipelines (e.g., redaction handler -> metrics-extraction handler -> output
handler). Common packages defininng attributes necessary across multiple libraries are expected.

### Detailed design

#### `MetadataAttributeKey` protocol

```swift
extension Logger {
    /// Defines a custom metadata attribute as a small, fixed-vocabulary enum with `Int64` raw values.
    /// Attributes that need associated data or richer payloads are outside the scope of this protocol —
    /// use the metadata value itself for structured data.
    public protocol MetadataAttributeKey: Sendable,
        RawRepresentable where RawValue == Int64 {}
}
```

Each conforming type serves as both the key and the value for an attribute. The metatype (`Key.Type`) identifies
the attribute at runtime — no coordination between packages is needed.

#### `MetadataValueAttributes`

```swift
extension Logger {
    /// Stores per-value attributes. One attribute is stored inline without heap allocation;
    /// additional attributes spill to a heap-allocated array.
    public struct MetadataValueAttributes: Sendable, Equatable {
        public init()
        public subscript<Key: MetadataAttributeKey>(key: Key.Type) -> Key? { get set }
    }
}
```

The common case (0–1 attributes) avoids heap allocation. `Equatable` compares entries as an unordered set (O(n²),
n typically 0–2).

#### `AttributedMetadataValue` and `AttributedMetadata`

```swift
extension Logger {
    /// A metadata value with associated attributes.
    public struct AttributedMetadataValue: Sendable, Equatable, CustomStringConvertible,
        ExpressibleByStringLiteral, ExpressibleByStringInterpolation
    {
        public var value: Logger.MetadataValue
        public var attributes: Logger.MetadataValueAttributes
        public init(_ value: Logger.MetadataValue, attributes: Logger.MetadataValueAttributes)
    }

    public typealias AttributedMetadata = [String: AttributedMetadataValue]
}
```

#### String interpolation

The `Logging` module provides two base interpolation methods on `AttributedMetadataValue.StringInterpolation`:

```swift
public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(_ value: T)

public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
    _ value: T,
    attributes: @Sendable (inout Logger.MetadataValueAttributes) -> Void
)
```

Attribute packages add ergonomic overloads that wrap the closure-based method — for example:

```swift
extension Logger.AttributedMetadataValue.StringInterpolation {
    public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
        _ value: T, sensitivity: Sensitivity
    ) {
        self.appendInterpolation(value, attributes: { $0[Sensitivity.self] = sensitivity })
    }
}
```

This enables the clean call-site syntax: `"\(userId, sensitivity: .sensitive)"`.

When a single `AttributedMetadataValue` contains multiple interpolated segments with different attributes, the merging
behavior is defined by each attribute's `appendInterpolation` implementation.

#### `Logger` API additions

New attributed metadata properties and subscripts:

```swift
extension Logger {
    public subscript(attributedMetadataKey key: String) -> Logger.AttributedMetadataValue? { get set }
    public var attributedMetadata: Logger.AttributedMetadata { get set }
}
```

New log method overloads accepting `attributedMetadata`. Each level (trace, debug, info, notice, warning, error,
critical) has a single overload with optional `error` and `source`, since attributed metadata is a new API with no
backward compatibility constraints:

```swift
extension Logger {
    /// Full overload with error and source.
    public func log(
        level: Logger.Level,
        _ message: @autoclosure () -> Logger.Message,
        error: @autoclosure () -> (any Error)? = nil,
        attributedMetadata: @autoclosure () -> Logger.AttributedMetadata?,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID, function: String = #function, line: UInt = #line
    )

    /// Per-level methods (trace, debug, ..., critical) follow the same single-overload pattern.
}
```

#### `LogEvent` attributed metadata support

`LogEvent` carries both plain and attributed metadata through a single internal storage enum. Handlers access whichever
representation they need via computed properties:

```swift
public struct LogEvent: Sendable {
    // ... existing properties (level, message, error, source, file, function, line) ...

    public var metadata: Logger.Metadata? { get set }
    public var attributedMetadata: Logger.AttributedMetadata? { get set }

    public init(
        level: Logger.Level, message: Logger.Message,
        error: (any Error)?,
        attributedMetadata: Logger.AttributedMetadata?,
        source: String?, file: String, function: String, line: UInt
    )
}
```

Both properties perform lazy conversion — accessing `attributedMetadata` on a plain-metadata event wraps values with
empty attributes; accessing `metadata` on an attributed-metadata event strips attributes. Neither direction allocates
until accessed.

The conversion cost is only paid by handlers that read the non-matching representation. Attribute-aware handlers read
`event.attributedMetadata` on attributed events with zero allocation. Since `LogEvent` is a value type, the conversion
is not cached across handlers in a multiplex setup.

**Performance guidance for handler authors.** Handlers that support attributed metadata should implement native
`attributedMetadata` storage rather than relying on the default `mapValues` bridge — the default allocates a new
dictionary on every access.

#### `LogHandler` protocol additions

```swift
public protocol LogHandler {
    // Existing requirements unchanged...

    subscript(attributedMetadataKey _: String) -> Logger.AttributedMetadataValue? { get set }
    var attributedMetadata: Logger.AttributedMetadata { get set }
}
```

All new requirements have default implementations that delegate `attributedMetadata` to `metadata`. Existing
`LogHandler` implementations continue to work without changes.

A handler may implement either `metadata` or `attributedMetadata` as its canonical store and derive the other.
`MultiplexLogHandler` forwards the `LogEvent` to each child handler, preserving attributed metadata.

Chained `LogHandler`s that process attributed metadata should read `event.attributedMetadata`, mutate the event, and
forward via `wrappedHandler.log(event:)` to preserve attributes for downstream handlers.

#### `MetadataProvider` extensions

```swift
extension Logger.MetadataProvider {
    /// Creates an attributed metadata provider. When accessed through `get()`, attributes are stripped.
    public static func attributed(
        _ provideMetadata: @escaping @Sendable () -> Logger.AttributedMetadata
    ) -> MetadataProvider

    /// Returns attributed metadata. For plain providers, wraps values with empty attributes.
    public func getAttributedMetadata() -> Logger.AttributedMetadata
}
```

The `multiplex(_:)` factory always returns an attributed provider. Each sub-provider's metadata is retrieved via
`getAttributedMetadata()`, which wraps plain providers' values with empty attributes. This uniform approach simplifies
the implementation — the minor `mapValues` cost when calling `get()` on the multiplex is negligible compared to the
logging overhead.

### API stability

- **Existing `Logger` users.** No changes to existing plain metadata API.
- **Existing `LogHandler` implementations.** Handlers that only read `event.metadata` continue to work — attributes
  are stripped automatically. Handlers that want to interpret attributes read `event.attributedMetadata` instead.

### Future directions

- **Sensitivity attribute.** A `Sensitivity` attribute (`.sensitive` / `.public`) could be provided as a companion
  target within `swift-log`, enabling call sites to mark metadata values for redaction by privacy-aware handlers.
- **Typed metadata values.** A separate ecosystem package could add typed variants to `MetadataValue` (`.int64`,
  `.double`, `.bool`), reducing the need for attributes that compensate for stringly-typed metadata.

### Alternatives considered

#### Concrete stored property instead of extensible mechanism

Add concrete stored properties (e.g., `var sensitivity: Sensitivity?`) on `MetadataValueAttributes`. Simpler, but
closed — chained handlers cannot define their own attributes. The extensible mechanism keeps the core `Logging` module
free of domain-specific attributes.

#### Bitmask storage

Pack attribute values into an inline `UInt64` using declared bit offsets. O(1) access, but requires authors to
coordinate bit layout and risks collisions between independent packages.

#### Pure dynamic array storage

Use a dynamic array for all attributes with no inline slot. Simpler, but requires heap allocation even for the first
attribute.

#### No per-value attributes

Rely on handler-side configuration (key-name-based rules). Simpler, but fragile — rules break when keys are renamed,
require coordination across all dependencies, and are invisible at the call site.

#### Sensitivity attribute as a companion target in `swift-log`

Ship a `LoggingAttributes` target alongside the core `Logging` module, providing a `Sensitivity` attribute out of the
box. This would give the ecosystem a shared vocabulary from day one. However, bundling a domain-specific attribute in
the core package sets a precedent for adding more over time. Keeping the core focused on the mechanism and letting
the ecosystem converge independently is the preferred approach.

### Example attributes

The following examples illustrate how ecosystem packages could define attributes using the `MetadataAttributeKey`
protocol. These are not part of this proposal.

#### Sensitivity

A sensitivity attribute for marking metadata values that contain private or personally identifiable information:

```swift
public enum Sensitivity: Int64, Logger.MetadataAttributeKey, Sendable {
    case sensitive = 1
    case `public` = 2
}

extension Logger.AttributedMetadataValue.StringInterpolation {
    public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
        _ value: T, sensitivity: Sensitivity
    ) {
        self.appendInterpolation(value, attributes: { $0[Sensitivity.self] = sensitivity })
    }
}

logger.info("Request", attributedMetadata: [
    "method": "\(req.method)",
    "user_id": "\(req.userId, sensitivity: .sensitive)",
])
```

#### Value type hint

A type hint for structured logging backends that benefit from native types:

```swift
public enum ValueType: Int64, Logger.MetadataAttributeKey, Sendable {
    case string = 1
    case int64 = 2
    case double = 3
    case bool = 4
}

extension Logger.AttributedMetadataValue.StringInterpolation {
    public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
        _ value: T, valueType: ValueType
    ) {
        self.appendInterpolation(value, attributes: { $0[ValueType.self] = valueType })
    }
}

logger.info("Metrics", attributedMetadata: [
    "latency_ms": "\(latency, valueType: .double)",
    "retry_count": "\(retries, valueType: .int64)",
])
```

#### Metric extraction

A metric attribute for a chained `LogHandler` that dual-writes to swift-metrics:

```swift
public enum MetricKind: Int64, Logger.MetadataAttributeKey, Sendable {
    case counter = 1
    case gauge = 2
    case histogram = 3
}

extension Logger.AttributedMetadataValue.StringInterpolation {
    public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
        _ value: T, metricKind: MetricKind
    ) {
        self.appendInterpolation(value, attributes: { $0[MetricKind.self] = metricKind })
    }
}

logger.info("Request completed", attributedMetadata: [
    "duration_ms": "\(duration, metricKind: .histogram)",
    "error_count": "\(errors, metricKind: .counter)",
])
```
