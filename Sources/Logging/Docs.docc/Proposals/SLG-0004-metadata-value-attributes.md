# SLG-0004: Metadata value attributes

Add an extensible per-value attribute mechanism for metadata.

## Overview

- Proposal: SLG-0004
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **Awaiting Review**
- Issue: [apple/swift-log#204](https://github.com/apple/swift-log/issues/204)
- Implementation:
    - [apple/swift-log#453](https://github.com/apple/swift-log/pull/453)
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

Attributes are embedded directly in `MetadataValue` via the existing `.stringConvertible` case. A custom
`MetadataValue.StringInterpolation` type produces attributed values when any interpolation segment specifies
attributes. Libraries define attribute types conforming to `MetadataAttributeKey` and provide ergonomic string
interpolation overloads. Handlers read the attributes via `value.attributes` and act on them:

```swift
import Logging

public enum Sensitivity: Int64, Logger.MetadataAttributeKey, Sendable {
    case sensitive = 1
    case `public` = 2
}

extension Logger.MetadataValue.StringInterpolation {
    public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
        _ value: T, sensitivity: Sensitivity
    ) {
        self.appendInterpolation(value, attributes: { $0[Sensitivity.self] = sensitivity })
    }
}

logger.info("Request", metadata: [
    "method": "\(req.method)",
    "user_id": "\(req.userId, sensitivity: .sensitive)",
])
```

Handlers that support specific attributes read them from `value.attributes` and act accordingly. Handlers that do not
understand attributes see plain `MetadataValue` instances — attributes are invisible unless explicitly inspected. The
existing `metadata:` parameter is the only parameter needed; no new log method overloads are added.

Attributed values can also be created programmatically with the `.attributed` factory, which behaves like an additional
enum case without breaking existing exhaustive switches:

```swift
let value: Logger.MetadataValue = .attributed(userId, attributes: [Sensitivity.sensitive])
```

Intermediate handlers can read **and modify** attributes as metadata flows through a handler chain. The `attributes`
property supports both getting and setting, enabling composable pipelines where each handler in the chain can enrich,
transform, or strip attributes before forwarding:

```swift
// An enriching handler that tags all metadata with a processing timestamp attribute
func log(event: LogEvent) {
    var mutatedEvent = event
    if var eventMetadata = event.metadata {
        for (key, _) in eventMetadata {
            var attrs = eventMetadata[key]!.attributes
            attrs[ProcessingStage.self] = .enriched
            eventMetadata[key]?.attributes = attrs
        }
        mutatedEvent.metadata = eventMetadata
    }
    self.inner.log(event: mutatedEvent)
}
```

Attributes are **classifications, not enforcement**. An attribute does not guarantee any particular handler behavior —
the handler may not support it. Applications needing guaranteed behavior must enforce it at a different abstraction.

The attribute mechanism is extensible: packages define their own attribute types using `MetadataAttributeKey`. A
chained `LogHandler` can read the attributes it cares about, act on them, and forward the rest to the next handler in
the chain — enabling composable handler pipelines (e.g., redaction handler -> metrics-extraction handler -> output
handler). Two common attributes — sensitivity and value type hints — will be defined in separate packages so that
the core `Logging` module remains free of domain-specific attributes while providing shared vocabulary across libraries.

### Detailed design

#### `MetadataAttributeKey` protocol

```swift
extension Logger {
    /// A protocol for defining custom metadata attribute keys.
    ///
    /// Conform to this protocol to define a custom attribute that can be stored in
    /// ``MetadataValueAttributes``. Each conforming type acts as both the key (identified
    /// by its metatype) and the value.
    ///
    /// This protocol is designed for **small, fixed-vocabulary attributes** represented as
    /// enums. Each attribute value is stored as an `Int64` raw value, so attributes occupy minimal
    /// space (one inline slot without heap allocation for the common single-attribute case).
    /// Attributes that need to carry associated data, strings, or richer payloads are outside
    /// the scope of this protocol.
    ///
    /// ## Example
    ///
    /// ```swift
    /// public enum Priority: Int64, Sendable, MetadataAttributeKey {
    ///     case low = 1
    ///     case high = 2
    /// }
    /// ```
    public protocol MetadataAttributeKey: Sendable,
        RawRepresentable where RawValue == Int64 {}
}
```

Each conforming type serves as both the key and the value for an attribute. The metatype (`Key.Type`) identifies
the attribute at runtime — no coordination between packages is needed.

#### `MetadataValueAttributes`

```swift
extension Logger {
    /// Attributes that can be associated with metadata values.
    ///
    /// `MetadataValueAttributes` stores one attribute inline without heap allocation. When more than one attribute
    /// is needed, additional attributes spill over to a heap-allocated array.
    /// Use the generic subscript to get/set attributes by their ``MetadataAttributeKey`` type.
    public struct MetadataValueAttributes: Sendable, Equatable, ExpressibleByArrayLiteral {
        /// Create empty metadata value attributes.
        public init()

        /// Create metadata value attributes from an array literal of attribute values.
        ///
        /// ```swift
        /// let attrs: MetadataValueAttributes = [Sensitivity.sensitive, ValueType.int64]
        /// ```
        public init(arrayLiteral elements: any MetadataAttributeKey...)

        /// Get or set a custom attribute by its key type.
        ///
        /// - Parameter key: The metatype of the attribute key to access.
        /// - Returns: The attribute value, or `nil` if not set.
        public subscript<Key: MetadataAttributeKey>(key: Key.Type) -> Key? { get set }
    }
}
```

The common case (0–1 attributes) avoids heap allocation. `Equatable` compares entries as an unordered set (O(n²),
n typically 0–2).

#### `MetadataValue.attributes` computed property

```swift
extension Logger.MetadataValue {
    /// The attributes associated with this metadata value, if any.
    ///
    /// **Getting:** When the value is a ``stringConvertible(_:)`` wrapping an attributed carrier,
    /// returns that carrier's attributes. For all other cases returns empty attributes.
    ///
    /// **Setting:** Replaces the value with `.stringConvertible(AttributedStringCarrier(...))`
    /// carrying the given attributes. For `.string` and `.stringConvertible` cases the string
    /// representation is preserved. For `.dictionary` and `.array` cases the setter is a no-op.
    public var attributes: Logger.MetadataValueAttributes { get set }
}
```

This is the handler-side read/write API. Internally, the `Logging` module stores attributes in an internal
`AttributedStringCarrier` class wrapped by `.stringConvertible`. The getter check is a concrete type comparison — no
protocol conformance lookup. Users attach attributes via string interpolation and read them via this property. The
setter allows handlers to modify or add attributes as they process metadata values through the handler chain.

#### `MetadataValue.attributed` factory method

```swift
extension Logger.MetadataValue {
    /// Creates an attributed metadata value from a string-convertible value and attributes.
    public static func attributed(
        _ value: some CustomStringConvertible & Sendable,
        attributes: Logger.MetadataValueAttributes
    ) -> Self
}
```

This convenience factory behaves like an additional enum case, producing a
`.stringConvertible(AttributedStringCarrier(...))` value without requiring string interpolation:

```swift
let value: Logger.MetadataValue = .attributed(userId, attributes: [Sensitivity.sensitive])
```

#### String interpolation

`MetadataValue` replaces its empty `ExpressibleByStringInterpolation` conformance with a custom `StringInterpolation`
type. When no attributes are specified, the result is `.string(...)` — identical to the previous behavior. When any
interpolation segment specifies attributes, the result is `.stringConvertible(...)` wrapping the internal carrier:
```swift
extension Logger.MetadataValue: ExpressibleByStringInterpolation {
    /// Custom string interpolation that optionally captures metadata attributes.
    ///
    /// When no attributes are specified, produces `.string(...)` — identical to the
    /// default `DefaultStringInterpolation` behavior. When any interpolation segment
    /// specifies attributes (via the `attributes:` parameter), the result is
    /// `.stringConvertible(AttributedStringCarrier(...))` carrying both the string
    /// and the accumulated attributes.
    ///
    /// Attribute packages (like `LoggingAttributes`) can add overloads with
    /// domain-specific parameters (e.g. `sensitivity:`) that call through to
    /// `appendInterpolation(_:attributes:)`.
    public struct StringInterpolation: StringInterpolationProtocol, Sendable {
        public init(literalCapacity: Int, interpolationCount: Int)
        public mutating func appendLiteral(_ literal: String)

        /// Interpolation with a custom attributes closure.
        ///
        /// When called, the result will be `.stringConvertible(AttributedStringCarrier(...))`
        /// instead of `.string(...)`.
        ///
        /// ```swift
        /// "\(userId, attributes: { $0[MyAttribute.self] = .flagged })"
        /// ```
        public mutating func appendInterpolation<T>(
            _ value: T,
            attributes: @Sendable (inout Logger.MetadataValueAttributes) -> Void
        ) where T: CustomStringConvertible & Sendable

        /// Plain interpolation without attributes.
        public mutating func appendInterpolation<T>(
            _ value: T
        ) where T: CustomStringConvertible & Sendable

        /// Fallback interpolation for types that are not `CustomStringConvertible`.
        public mutating func appendInterpolation<T>(
            _ value: T
        ) where T: Sendable

        /// Unconstrained fallback for non-`Sendable` types.
        ///
        /// The value is immediately converted to `String` via `String(describing:)` and never
        /// stored, so no `Sendable` safety issue arises. This overload exists so that interpolating
        /// a non-`Sendable` type into a `MetadataValue` continues to compile, matching the behavior
        /// of `DefaultStringInterpolation`.
        public mutating func appendInterpolation<T>(
            _ value: T
        )
    }

    /// Creates a metadata value from string interpolation.
    ///
    /// If any interpolation segment specified attributes, the result is
    /// `.stringConvertible(AttributedStringCarrier(...))`. Otherwise, `.string(...)`.
    public init(stringInterpolation: StringInterpolation)
}
```

Attribute packages add ergonomic overloads that wrap the closure-based method — for example:

```swift
extension Logger.MetadataValue.StringInterpolation {
    public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
        _ value: T, sensitivity: Sensitivity
    ) {
        self.appendInterpolation(value, attributes: { $0[Sensitivity.self] = sensitivity })
    }
}
```

This enables the clean call-site syntax: `"\(userId, sensitivity: .sensitive)"`.

When a single `MetadataValue` contains multiple interpolated segments with different attributes, the merging behavior
is defined by each attribute's `appendInterpolation` implementation.

#### No changes to `Logger`, `LogHandler`, `LogEvent`, or `MetadataProvider`

Unlike earlier iterations of this proposal, the piggyback approach requires **no new API** on `Logger`, `LogHandler`,
`LogEvent`, or `MetadataProvider`:

- **`Logger`**: No new `attributedMetadata:` log method overloads. Attributes flow through the existing `metadata:`
  parameter.
- **`LogHandler`**: No new protocol requirements. No `attributedMetadata` property, no `attributedMetadataKey`
  subscript. Existing handlers work unchanged.
- **`LogEvent`**: No dual storage. `metadata` remains a simple `Logger.Metadata?` stored property. Values inside the
  dictionary may carry attributes, but `LogEvent` is unaware of this.
- **`MetadataProvider`**: No `.attributed()` factory or `getAttributedMetadata()` method. Providers return
  `Logger.Metadata` where values may carry attributes via string interpolation.

### API stability

- **Existing `Logger` users.** No changes to existing API. The same `metadata:` parameter carries attributed values.
- **Existing `LogHandler` implementations.** No protocol changes. Handlers that only call `.description` on metadata
  values see the string as before — attributes are invisible. Handlers that want to inspect attributes read
  `value.attributes`.

### Future directions

- **Attribute-aware equality.** The current `MetadataValue` equality for `.stringConvertible` values compares only
  `.description`, ignoring attributes. Two values with the same text but different attributes compare as equal. A
  future proposal could refine equality to include attributes when both sides carry them, but this
  requires careful consideration of backward compatibility since existing code may rely on description-only equality.
- **Recursive attribute inspection.** The `.attributes` property only inspects top-level values. Metadata values nested
  inside `.dictionary` or `.array` cases carry their own attributes on leaf values, but handler-level iteration (for
  example, redaction) operates on top-level entries only. A future proposal could introduce recursive attribute
  traversal utilities for handlers that need deep inspection.
- **Typed metadata values.** A separate ecosystem package could add typed variants to `MetadataValue` (`.int64`,
  `.double`, `.bool`), reducing the need for attributes that compensate for stringly-typed metadata.

### Alternatives considered

#### Wrapper type with parallel API ("attributed metadata value" approach)

Introduce an `AttributedMetadataValue` struct wrapping `MetadataValue` + `MetadataValueAttributes`, a separate
`AttributedMetadata` typealias, new `attributedMetadata:` overloads on all Logger methods, dual storage in
`LogEvent`, and new `LogHandler` protocol requirements. This was the design in the first iteration of this proposal.

It provides strong type separation but creates a parallel API surface: 7 new convenience methods, new protocol
requirements with default implementations, dual `MetadataStorage` enum in `LogEvent`, and `mapValues` bridging
between plain and attributed representations. The piggyback approach achieves the same functionality by embedding
attributes inside `MetadataValue` via the existing `.stringConvertible` case, avoiding the parallel universe
entirely.

#### Sidecar dictionary on `LogEvent`

Store attributes in a separate `[String: MetadataValueAttributes]` dictionary on `LogEvent`, keyed by the same
metadata keys. This keeps `MetadataValue` unchanged but introduces sync issues — attributes can drift out of sync
with metadata keys when handlers merge or transform metadata. The piggyback approach avoids this by co-locating
attributes with the value they describe.

#### New enum case on `MetadataValue`

Add a dedicated `.attributed(String, MetadataValueAttributes)` case to the `MetadataValue` enum. This would make
attributes statically visible in the type — no runtime downcast needed, and `switch` statements would handle
attributed values explicitly. However, `MetadataValue` is a public enum that is exhaustively matched by every
`LogHandler` in the ecosystem. Adding a case is source-breaking: every existing handler's `switch` over
`MetadataValue` would fail to compile until updated. The piggyback approach avoids this by reusing the existing
`.stringConvertible` case, which handlers already handle.

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

extension Logger.MetadataValue.StringInterpolation {
    public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
        _ value: T, sensitivity: Sensitivity
    ) {
        self.appendInterpolation(value, attributes: { $0[Sensitivity.self] = sensitivity })
    }
}

logger.info("Request", metadata: [
    "method": "\(req.method)",
    "user_id": "\(req.userId, sensitivity: .sensitive)",
])
```

A handler reads the attribute:

```swift
for (key, value) in mergedMetadata {
    if value.attributes[Sensitivity.self] == .sensitive {
        // redact this value
    }
}
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

extension Logger.MetadataValue.StringInterpolation {
    public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
        _ value: T, valueType: ValueType
    ) {
        self.appendInterpolation(value, attributes: { $0[ValueType.self] = valueType })
    }
}

logger.info("Metrics", metadata: [
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

extension Logger.MetadataValue.StringInterpolation {
    public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
        _ value: T, metricKind: MetricKind
    ) {
        self.appendInterpolation(value, attributes: { $0[MetricKind.self] = metricKind })
    }
}

logger.info("Request completed", metadata: [
    "duration_ms": "\(duration, metricKind: .histogram)",
    "error_count": "\(errors, metricKind: .counter)",
])
```

#### Attribute-enriching intermediate handler

An intermediate `LogHandler` that reads and modifies attributes before forwarding to the next handler in the chain.
This pattern enables composable pipelines — for example, a handler that adds a default sensitivity to all metadata
values that do not already carry one:

```swift
struct DefaultSensitivityHandler: LogHandler {
    private var inner: any LogHandler

    // ... logLevel, metadata, metadataProvider forwarded to inner ...

    func log(event: LogEvent) {
        var mutatedEvent = event
        if var eventMetadata = event.metadata {
            for (key, _) in eventMetadata {
                if eventMetadata[key]?.attributes[Sensitivity.self] == nil {
                    eventMetadata[key]?.attributes = [Sensitivity.sensitive]
                }
            }
            mutatedEvent.metadata = eventMetadata
        }
        self.inner.log(event: mutatedEvent)
    }
}
```

With this handler in the chain, any metadata value without an explicit sensitivity annotation is treated as sensitive
by default — a "deny by default" policy that individual call sites can override with `.public`.
