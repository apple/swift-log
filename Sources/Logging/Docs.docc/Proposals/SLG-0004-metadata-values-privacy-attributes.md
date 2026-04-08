# SLG-0004: Metadata value attributes

Add an extensible per-value attribute mechanism for metadata, with sensitivity as the first attribute.

## Overview

- Proposal: SLG-0004
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **Awaiting Review**
- Issue: [apple/swift-log#204](https://github.com/apple/swift-log/issues/204)
- Implementation:
    - [apple/swift-log#439](https://github.com/apple/swift-log/pull/439)
- Related links:
    - [Lightweight proposals process description](https://github.com/apple/swift-log/blob/main/Sources/Logging/Docs.docc/Proposals/Proposals.md)

### Introduction

Introduce an extensible mechanism for attaching per-value attributes to metadata. The core `Logging` module provides
the protocol and storage. A companion `LoggingAttributes` target provides the first cross-cutting attribute:
`Sensitivity` (`.sensitive` / `.public`).

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
- The rule mapping is invisible at the call site — the developer has no indication whether their handler will redact.

The alternative is to apply redaction logic on the emission site, but this is verbose and also error-prone.

### Proposed solution

A new `attributedMetadata` parameter on `Logger` log methods accepts metadata values wrapped with attributes. Libraries
import the `LoggingAttributes` companion target to annotate values; handlers read the attributes and act on them:

```swift
import Logging
import LoggingAttributes

logger.info("Request", attributedMetadata: [
    "method": "\(req.method)",
    "user_id": "\(req.userId, sensitivity: .sensitive)",
])
```

Handlers that support redaction replace or mask the value. Handlers that do not support redaction simply read
`event.metadata`, which strips attributes and returns raw values automatically.
The existing `metadata:` parameter continues to work unchanged.

Attributes are **classifications, not enforcement**. A sensitivity attribute does not guarantee redaction — the handler
may not support it. Applications needing guaranteed PII protection must enforce it at the application level.

The attribute mechanism is extensible: handler packages and middleware can define their own attribute types using the
same `MetadataAttributeKey` protocol. A `LogHandler` middleware can read the attributes it cares about, act on them,
and forward the rest to the next handler in the chain. This enables composable handler pipelines — for example,
a sensitivity-aware middleware followed by a metrics-extraction middleware followed by the output handler.
Handler-specific attributes couple the call site to that handler and should only be used by application code
or by code that controls both the emission site and the `LogHandler`.

### Detailed design

#### `MetadataAttributeKey` protocol

```swift
extension Logger {
    /// A protocol for defining custom metadata attribute keys.
    ///
    /// This protocol is designed for **small, fixed-vocabulary attributes** represented as
    /// enums. Each attribute value is stored as an `Int` raw value alongside an `ObjectIdentifier`
    /// for the key type, so attributes occupy minimal space. Attributes that need to carry
    /// associated data, strings, or richer payloads are outside the scope of this protocol.
    ///
    /// The conforming type must be an enum with `Int` raw values. Each attribute occupies just
    /// `(ObjectIdentifier, Int)` in the inline slot, avoiding heap allocation for the
    /// common single-attribute case.
    ///
    /// ## Example
    ///
    /// ```swift
    /// public enum Sensitivity: Int, Sendable, MetadataAttributeKey {
    ///     case sensitive = 1
    ///     case `public` = 2
    /// }
    /// ```
    public protocol MetadataAttributeKey: Sendable,
        RawRepresentable where RawValue == Int {}
}
```

Each conforming type serves as both the key and the value for an attribute. The metatype (`Key.Type`) identifies
the attribute at runtime via `ObjectIdentifier` — no coordination between packages is needed.

#### `MetadataValueAttributes`

```swift
extension Logger {
    /// Attributes that can be associated with metadata values.
    ///
    /// `MetadataValueAttributes` stores one attribute inline without heap allocation. When more
    /// than one attribute is needed, additional attributes spill over to a heap-allocated array.
    /// Use the generic subscript to get/set attributes by their ``MetadataAttributeKey`` type.
    public struct MetadataValueAttributes: Sendable, Equatable {
        /// Create empty metadata value attributes.
        public init()

        /// Get or set a custom attribute by its key type.
        ///
        /// - Parameter key: The metatype of the attribute key to access.
        /// - Returns: The attribute value, or `nil` if not set.
        public subscript<Key: MetadataAttributeKey>(key: Key.Type) -> Key? { get set }
    }
}
```

The common case (0–1 attributes) avoids heap allocation. `Equatable` compares entries as an unordered set,
which is O(n²) but n is typically 0 or close to 0.

#### `AttributedMetadataValue` and `AttributedMetadata`

```swift
extension Logger {
    /// A metadata value with associated attributes.
    ///
    /// `AttributedMetadataValue` wraps a standard `MetadataValue` with custom attributes,
    /// allowing you to associate application-defined or handler-defined attributes
    /// with metadata values.
    public struct AttributedMetadataValue: Sendable, Equatable, CustomStringConvertible,
        ExpressibleByStringLiteral, ExpressibleByStringInterpolation
    {
        /// The underlying metadata value without attributes.
        public var value: Logger.MetadataValue

        /// The attributes associated with this metadata value.
        public var attributes: Logger.MetadataValueAttributes

        /// Create an attributed metadata value with the specified attributes.
        public init(_ value: Logger.MetadataValue, attributes: Logger.MetadataValueAttributes)
    }

    /// Metadata dictionary with attributes.
    public typealias AttributedMetadata = [String: AttributedMetadataValue]
}
```

`description` returns the value's string representation with no post-processing. Handlers that understand specific
attributes perform post-processing in their `log(event:)` method.

#### String interpolation

The `Logging` module provides two base interpolation methods on `AttributedMetadataValue.StringInterpolation`:

```swift
/// Plain interpolation without attributes.
public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(_ value: T)

/// Interpolation with a custom attributes closure.
public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
    _ value: T,
    attributes: @Sendable (inout Logger.MetadataValueAttributes) -> Void
)
```

Attribute packages add ergonomic overloads. The `LoggingAttributes` target adds:

```swift
/// Interpolation with explicit sensitivity parameter.
public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
    _ value: T, sensitivity: Logger.Sensitivity
)
```

When a single `AttributedMetadataValue` contains multiple interpolated segments with different attributes, the merging
behavior is defined by each attribute's `appendInterpolation` implementation. For sensitivity, the strictest level
wins — if any segment is `.sensitive`, the entire value is `.sensitive`.

#### `Logger` API additions

New attributed metadata properties and subscripts on `Logger`:

```swift
extension Logger {
    /// Get or set an attributed metadata value by key.
    public subscript(attributedMetadataKey attributedMetadataKey: String)
        -> Logger.AttributedMetadataValue? { get set }

    /// Get or set the entire attributed metadata storage.
    public var attributedMetadata: Logger.AttributedMetadata { get set }
}
```

New log method overloads accepting `attributedMetadata`:

```swift
extension Logger {
    /// Log a message with attributed metadata at the specified level.
    public func log(
        level: Logger.Level,
        _ message: @autoclosure () -> Logger.Message,
        attributedMetadata: @autoclosure () -> Logger.AttributedMetadata?,
        source: @autoclosure () -> String? = nil,
        file: String = #fileID, function: String = #function, line: UInt = #line
    )

    /// Convenience methods for each log level (trace, debug, info, notice, warning, error, critical).
    /// Each follows the same signature pattern with the level fixed.
}
```

#### `LogEvent` attributed metadata support

`LogEvent` carries both plain and attributed metadata through a single internal storage enum. Handlers access whichever
representation they need via computed properties:

```swift
public struct LogEvent: Sendable {
    // ... existing properties (level, message, source, file, function, line) ...

    /// The metadata associated with this event, if any.
    ///
    /// When the event was created with attributed metadata, accessing this property
    /// strips attributes and returns raw values.
    public var metadata: Logger.Metadata? { get set }

    /// The attributed metadata associated with this event, if any.
    ///
    /// When the event was created with plain metadata, accessing this property wraps
    /// values with empty attributes.
    public var attributedMetadata: Logger.AttributedMetadata? { get set }

    /// Creates a new log event with attributed metadata.
    public init(
        level: Logger.Level, message: Logger.Message,
        attributedMetadata: Logger.AttributedMetadata?,
        source: String?, file: String, function: String, line: UInt
    )
}
```

Both properties perform lazy conversion — accessing `attributedMetadata` on a plain-metadata event wraps values with
empty attributes; accessing `metadata` on an attributed-metadata event strips attributes. Neither direction allocates
until accessed. Setting either property replaces the stored value.

The conversion allocates a new dictionary, but each `LogEvent` is created once at the emission site and consumed by
a single `handler.log(event:)` call, so this cost is paid at most once per log statement. Handlers that want to
avoid this cost should read the representation matching how the event was created — `event.attributedMetadata` for
events created with `attributedMetadata:`, and `event.metadata` for events created with `metadata:`.

`Logger.log(level:_:attributedMetadata:...)` creates a `LogEvent` with `attributedMetadata` and calls
`handler.log(event:)` — the same entry point used for plain metadata. Handlers that want to inspect attributes read
`event.attributedMetadata`; handlers that only care about raw values read `event.metadata`.

#### `LogHandler` protocol additions

```swift
public protocol LogHandler {
    // Existing requirements unchanged...
    // log(event:) is the single entry point for all log messages.

    /// Add, remove, or change the attributed logging metadata.
    ///
    /// - note: `LogHandler`s must treat logging metadata as a value type.
    subscript(attributedMetadataKey _: String) -> Logger.AttributedMetadataValue? { get set }

    /// Get or set the entire attributed metadata storage as a dictionary.
    ///
    /// - note: `LogHandler`s must treat logging metadata as a value type.
    var attributedMetadata: Logger.AttributedMetadata { get set }
}
```

All new requirements have default implementations. The default `attributedMetadata` property delegates to `metadata`.
Existing `LogHandler` implementations continue to work without changes.

The `metadata` and `attributedMetadata` properties are two views of the same logical storage. A handler may implement
either as its canonical store and derive the other. Setting a value through `metadata` is visible through
`attributedMetadata` (with empty attributes), and setting a value through `attributedMetadata` is visible through
`metadata` (with attributes stripped). The default implementations achieve this by delegating `attributedMetadata` to
`metadata`.

`MultiplexLogHandler` forwards the `LogEvent` to each child handler via `log(event:)`, preserving attributed metadata
for handlers that support them.

Middleware that processes attributed metadata should read `event.attributedMetadata`, mutate the event, and forward
via `wrappedHandler.log(event:)` to preserve attributes for downstream handlers in the chain.

#### `MetadataProvider` extensions

`MetadataProvider` gains an attributed variant so providers can attach attributes to contextual metadata:

```swift
extension Logger.MetadataProvider {
    /// Creates a new metadata provider that returns attributed metadata.
    ///
    /// When accessed through the plain `get()` method (for backward compatibility),
    /// attributes are stripped and raw values are returned.
    @_disfavoredOverload
    public init(_ provideMetadata: @escaping @Sendable () -> Logger.AttributedMetadata)

    /// Returns attributed metadata from this provider.
    ///
    /// For attributed providers, returns the full attributed metadata including all attributes.
    /// For plain providers, wraps each value with empty attributes so handlers always get a
    /// uniform `AttributedMetadata` dictionary without branching on provider kind.
    public func getAttributed() -> Logger.AttributedMetadata
}
```

The existing `get()` method continues to return plain `Metadata`. When called on an attributed provider, it strips
attributes and returns raw values. `getAttributed()` always returns `AttributedMetadata` — for plain providers,
values are wrapped with empty attributes. This eliminates the need for handlers to branch on provider kind.

The `multiplex(_:)` factory checks whether any sub-provider is attributed. If so, the multiplex provider itself
becomes attributed, combining all providers' metadata with attributes preserved (plain providers' values are wrapped
with empty attributes). If all providers are plain, a plain provider is returned for backward compatibility.

#### `LoggingAttributes` companion target

```swift
extension Logger {
    /// Sensitivity classification for metadata values.
    ///
    /// Classifies whether a metadata value contains sensitive data. This is a classification
    /// hint — the handler decides what action to take (redact, encrypt, log as-is, etc.).
    @frozen
    public enum Sensitivity: Int, MetadataAttributeKey, Sendable, CaseIterable,
        Equatable, Hashable, CustomStringConvertible
    {
        /// This value contains sensitive data that handlers may choose to redact.
        case sensitive = 1

        /// This value is safe to emit as-is.
        case `public` = 2
    }
}

extension Logger.MetadataValueAttributes {
    /// The sensitivity classification for this metadata value, if set.
    public var sensitivity: Logger.Sensitivity? { get set }
}

extension Logger.AttributedMetadataValue.StringInterpolation {
    /// Interpolation with explicit sensitivity parameter.
    public mutating func appendInterpolation<T: CustomStringConvertible & Sendable>(
        _ value: T, sensitivity: Logger.Sensitivity
    )
}
```

### Benchmarks

The `NoTraits` and `MaxLogLevelWarning` benchmark suites include `_attributed_generic` variants that measure the
attributed metadata code path alongside the existing plain metadata path. These benchmarks cover both the
above-threshold case (message emitted) and below-threshold case (message skipped via `@autoclosure`).

### API stability

- **Existing `Logger` users.** No changes to existing plain metadata API. The `metadata:` parameter continues to work
  as before.
- **Existing `LogHandler` implementations.** Attributed metadata flows through `LogEvent`, which handlers already
  receive via `log(event:)`. Handlers that only read `event.metadata` continue to work — plain values are returned
  with attributes stripped. Handlers that want to interpret attributes read `event.attributedMetadata` instead.
  Existing handlers work without changes.

### Future directions

- **Metrics extraction middleware.** A `LogHandler` middleware that reads a metric attribute and dual-writes to
  swift-metrics. The call site annotates a value as a counter or histogram, and the middleware updates the metric then
  forwards the attributed metadata to the next handler.
- **Cardinality hints.** An attribute indicating whether a field is safe to index as a label/dimension in observability
  backends. Only the call site knows a field's cardinality ahead of time.
- **Typed metadata values.** Adding typed variants to `MetadataValue` (`.int64`, `.double`, `.bool`) would reduce the
  need for attributes that compensate for stringly-typed metadata.
- **More stored slots.** If real-world usage shows growth in the number of attributes per value, it would make sense
  to increase the number of inline slots to avoid dynamic allocation in most use cases.

### Alternatives considered

#### Sensitivity in the core `Logging` module

Define `Sensitivity` directly in `Logging`. Simpler for users (no extra import), but accumulates domain-specific
attributes in the core module. The companion target approach keeps `Logging` focused on the API and mechanism.

#### Concrete stored property instead of extensible mechanism

Add `var sensitivity: Sensitivity?` as a stored property on `MetadataValueAttributes`. Smaller and simpler, but
closed — middleware handlers cannot define their own attributes using the same mechanism. The extensible mechanism
enables composable `LogHandler` middleware where each middleware defines its own attribute type, reads only the
attributes it cares about, and forwards the rest intact. A stored property would require all middleware attributes to
be fields in a single struct, coordinated upfront. The extensible mechanism also keeps the core `Logging` module free
of domain-specific attributes.

#### Bitmask storage

Pack attribute values into an inline `UInt64` using declared bit offsets. Smaller struct and O(1) access, but requires
authors to coordinate bit layout and risks collisions between independent packages.

#### Pure dynamic array storage

Use `[(ObjectIdentifier, Int)]` for all attributes with no inline slot. Simpler, but requires heap allocation even
for the first attribute.

#### No per-value attributes

Rely on handler-side configuration (key-name-based rules). Simpler, but key-based rules are fragile — they break when
keys are renamed, require coordination across all dependencies, and are invisible at the call site.

#### Naming: `.private` / `.public` instead of `.sensitive` / `.public`

Matches Apple's `OSLogPrivacy` convention, but `.private` implies a security guarantee that this API explicitly
disclaims. `Sensitivity` classifies the data without prescribing handler behavior — the handler decides whether to
redact, encrypt, or log as-is.

#### Naming: `.redact` / `.public`

Uses a verb (`.redact`) as an instruction to the handler. However, the asymmetry between a verb and an adjective
is unintuitive, and the attribute is a data classification, not an action directive. `.sensitive` / `.public` are
both adjectives that classify the data symmetrically.
