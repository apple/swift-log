# SLG-0004: Metadata values privacy attribute

Introduce an attributed metadata system that allows attaching attributes to metadata values, with privacy level as the first attribute enabling developers to mark metadata as `.private` or `.public`.

## Overview

- Proposal: SLG-0004
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **Awaiting Review**
- Issue: https://github.com/apple/swift-log/issues/204
- Implementation: TBD
- Related links:
    - [Lightweight proposals process description](https://github.com/apple/swift-log/blob/main/Sources/Logging/Docs.docc/Proposals/Proposals.md)

### Introduction

This proposal introduces an **attributed metadata system** that allows attaching attributes to metadata values. Privacy level is the first concrete attribute, enabling developers to mark metadata values as `.private` or `.public` so `LogHandler` implementations can redact sensitive values before logging.

### Motivation

SwiftLog lacks a mechanism to attach attributes to metadata values. This prevents marking metadata as sensitive and limits future extensibility for other metadata attributes.

Applications need privacy controls for:
- Compliance with privacy regulations.
- Backend integration with privacy-aware logging systems.
- Systematic control over what data appears in logs.

Beyond privacy, an attributed metadata system provides a foundation for future extensions such as retention policies, data classification, or other metadata attributes.

### Proposed solution

Introduce new `AttributedMetadata` data type, enabling users to mark metadata values with `.private` and `.public` privacy label:

```swift
// Add privacy level to metadata values obtained through a metadata provider
let serviceIp = "127.0.0.1"
var logger = Logger(label: "my-app", metadataProvider: .init {[
    "service.ip": "\(serviceIp, privacy: .private)",
]})

// Add privacy level to metadata values attached to a `Loghandler` instance
let requestId = UUID()
logger[attributedMetadataKey: "request.id"] = "\(requestId, privacy: .private)"

// Mark sensitive values as private and non-sensitive as public at logging call site
let userId = UUID()
let action = "login"
logger.info("User action", attributedMetadata: [
    "user.id": "\(userId, privacy: .private)",
    "action": "\(action)"  // default is .public for ease of adoption
])
```

### Detailed design

#### Attributed Metadata

To support privacy labels and enable future extensibility, we introduce a generalized **attributed metadata** system. This provides a foundation for attaching arbitrary attributes to metadata values, with privacy labels being the first concrete use case:

```swift
// Plain metadata (existing)
let metadataValue: MetadataValue = .string("value")
logger.info("Message", metadata: ["key": metadataValue])

// Attributed metadata (new) — a value with attributes
logger.info("Message", attributedMetadata: [
    "key": AttributedMetadataValue(value: metadataValue, attributes: ...)
])
```

The attributed metadata system instroduces new public API:

1. **`AttributedMetadataValue`**: Wraps a standard `MetadataValue` with associated attributes.
2. **`MetadataValueAttributes`**: Container for attributes.
3. **`AttributedMetadata`**: Dictionary type mapping `String` keys to attributed values.
4. **Parallel logging API**: New log methods accepting `attributedMetadata` parameter.

This design separates the transport mechanism (attributed metadata) from specific attribute semantics (privacy labels), allowing future extensions without breaking existing attributed metadata code.

#### Privacy levels

With attributed metadata as the foundation, privacy labels are implemented as the first concrete attribute:

```swift
extension Logger {
    /// A metadata value with associated privacy attributes.
    ///
    /// `AttributedMetadataValue` wraps a standard `MetadataValue` with privacy attributes,
    /// allowing you to mark metadata as private or public for privacy-aware logging.
    ///
    /// ## Creating Attributed Metadata
    ///
    /// Use string interpolation with privacy parameter:
    ///
    /// ```swift
    /// // Preferred: String interpolation with privacy level specified
    /// let userId = "12345"
    /// let action = "login"
    /// logger.info("User action", attributedMetadata: [
    ///     "user.id": "\(userId, privacy: .private)",
    ///     "action": "\(action, privacy: .public)"  // explicit .public for non-sensitive data
    /// ])
    ///
    /// // Direct creation
    /// let attributed = Logger.AttributedMetadataValue(
    ///     .string("12345"),
    ///     privacy: .private
    /// )
    /// ```
    ///
    /// ## Important Limitations
    ///
    /// - **No nested privacy**: When marking a dictionary or array as private, all contained
    ///   values are treated with the same privacy level. Fine-grained privacy within nested
    ///   structures is not currently supported.
    ///
    /// - **Metadata only**: Privacy levels apply only to metadata values, not to log messages.
    ///   Avoid including sensitive data in log message string interpolation.
    public struct AttributedMetadataValue: CustomStringConvertible, Sendable {
        /// The redaction marker used for private values.
        internal static let redactionMarker = "<private>"

        public let value: MetadataValue
        public let attributes: MetadataValueAttributes

        /// String representation redacts private values to the redaction marker.
        public var description: String {
            attributes.privacy == .public ? value.description : Self.redactionMarker
        }

        public init(_ value: MetadataValue, attributes: MetadataValueAttributes)
        public init(_ value: MetadataValue, privacy: PrivacyLevel)
    }

    extension AttributedMetadataValue {
        /// Attributes that can be associated with metadata values.
        public struct MetadataValueAttributes: CustomStringConvertible, Hashable, Sendable {
            /// Privacy level for metadata values.
            ///
            /// Privacy levels allow you to mark metadata values as either private (sensitive data that should be
            /// protected) or public (safe to log in any context).
            ///
            /// ## Usage
            ///
            /// Use string interpolation with the privacy parameter to create attributed metadata values:
            ///
            /// ```swift
            /// let userId = "12345"
            /// let action = "login"
            /// logger.info("User action", attributedMetadata: [
            ///     "user.id": "\(userId, privacy: .private)",
            ///     "action": "\(action, privacy: .public)",
            ///     "ip": "\(ipAddress, privacy: .private)"
            /// ])
            /// ```
            @frozen
            public enum PrivacyLevel: String, CustomStringConvertible, Hashable, Sendable, CaseIterable, Codable {
                /// Private data that should be redacted in non-secure contexts.
                case `private` = "private"

                /// Public data safe for general logging.
                case `public` = "public"

                public var description: String { self.rawValue }
            }

            /// The privacy level of this metadata value.
            public var privacy: PrivacyLevel

            /// Create metadata value attributes with the specified privacy level.
            ///
            /// - Parameter privacy: The privacy level for this metadata. Defaults to `.public`.
            public init(privacy: PrivacyLevel = .public)
        }

        /// The underlying metadata value without privacy attributes.
        public var value: MetadataValue

        /// The privacy attributes associated with this metadata value.
        public var attributes: MetadataValueAttributes

        /// Create an attributed metadata value with the specified attributes.
        ///
        /// - Parameters:
        ///   - value: The metadata value to wrap.
        ///   - attributes: The attributes for this value.
        public init(_ value: MetadataValue, attributes: MetadataValueAttributes)

        /// Convenience initializer for creating attributed metadata with a privacy level.
        ///
        /// - Parameters:
        ///   - value: The metadata value to wrap.
        ///   - privacy: The privacy level for this value.
        public init(_ value: MetadataValue, privacy: PrivacyLevel)
    }

    /// Metadata dictionary with privacy attributes.
    ///
    /// A dictionary mapping string keys to ``AttributedMetadataValue`` instances, used with
    /// the `attributedMetadata` parameter of logging methods.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let userId = "12345"
    /// let requestId = "req-789"
    /// let metadata: Logger.AttributedMetadata = [
    ///     "user.id": "\(userId, privacy: .private)",
    ///     "request.id": "\(requestId, privacy: .public)",
    ///     "action": "purchase"  // String literal defaults to .public
    /// ]
    /// logger.info("User action", attributedMetadata: metadata)
    /// ```
    public typealias AttributedMetadata = [String: AttributedMetadataValue]
}
```

#### String interpolation for attributed metadata

```swift
extension Logger.AttributedMetadataValue: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    /// Custom string interpolation that captures privacy levels from interpolated values.
    ///
    /// This enables syntax like:
    /// ```swift
    /// logger.info("User action", attributedMetadata: [
    ///     "user.id": "\(userId, privacy: .private)",
    ///     "action": "\(action, privacy: .public)"
    /// ])
    /// ```
    public struct StringInterpolation: StringInterpolationProtocol {
        public init(literalCapacity: Int, interpolationCount: Int)
        public mutating func appendLiteral(_ literal: String)

        /// Interpolation with explicit privacy parameter.
        public mutating func appendInterpolation<T>(_ value: T, privacy: Logger.PrivacyLevel = .public)
            where T: CustomStringConvertible
    }

    /// Creates an attributed metadata value from a string literal (defaults to .public).
    public init(stringLiteral value: String)

    /// Creates an attributed metadata value from string interpolation.
    public init(stringInterpolation: StringInterpolation)
}
```

#### New Logger methods

```swift
extension Logger {
    // Attributed metadata storage
    var attributedMetadata: Logger.AttributedMetadata { get set }
    subscript(attributedMetadataKey: String) -> Logger.AttributedMetadataValue? { get set }

    // Log family of methods
    public func log(level: Level, _ message: @autoclosure () -> Message,
                   attributedMetadata: @autoclosure () -> AttributedMetadata?,
                   source: @autoclosure () -> String? = nil,
                   file: String = #fileID, function: String = #function, line: UInt = #line)
    public func trace(_ message: @autoclosure () -> Message,
                     attributedMetadata: @autoclosure () -> AttributedMetadata?,
                     source: @autoclosure () -> String? = nil,
                     file: String = #fileID, function: String = #function, line: UInt = #line)
    public func debug(_ message: @autoclosure () -> Message,
                     attributedMetadata: @autoclosure () -> AttributedMetadata?,
                     source: @autoclosure () -> String? = nil,
                     file: String = #fileID, function: String = #function, line: UInt = #line)
    public func info(_ message: @autoclosure () -> Message,
                    attributedMetadata: @autoclosure () -> AttributedMetadata?,
                    source: @autoclosure () -> String? = nil,
                    file: String = #fileID, function: String = #function, line: UInt = #line)
    public func notice(_ message: @autoclosure () -> Message,
                      attributedMetadata: @autoclosure () -> AttributedMetadata?,
                      source: @autoclosure () -> String? = nil,
                      file: String = #fileID, function: String = #function, line: UInt = #line)
    public func warning(_ message: @autoclosure () -> Message,
                       attributedMetadata: @autoclosure () -> AttributedMetadata?,
                       source: @autoclosure () -> String? = nil,
                       file: String = #fileID, function: String = #function, line: UInt = #line)
    public func error(_ message: @autoclosure () -> Message,
                     attributedMetadata: @autoclosure () -> AttributedMetadata?,
                     source: @autoclosure () -> String? = nil,
                     file: String = #fileID, function: String = #function, line: UInt = #line)
    public func critical(_ message: @autoclosure () -> Message,
                        attributedMetadata: @autoclosure () -> AttributedMetadata?,
                        source: @autoclosure () -> String? = nil,
                        file: String = #fileID, function: String = #function, line: UInt = #line)
}
```

#### AttributedMetadata support in LogHandler protocol

```swift
protocol LogHandler {
    @available(
        *,
        deprecated,
        message: "Use generalized log(level:message:attributedMetadata:source:file:function:line:) instead."
    )
    func log(level: Logger.Level, message: Logger.Message,
            metadata: Logger.Metadata?, source: String,
            file: String, function: String, line: UInt)

    func log(level: Logger.Level, message: Logger.Message,
            attributedMetadata: Logger.AttributedMetadata?, source: String,
            file: String, function: String, line: UInt)

    var attributedMetadata: Logger.AttributedMetadata { get set }
    subscript(attributedMetadataKey: String) -> Logger.AttributedMetadataValue? { get set }
}

// Default implementations provided for backward compatibility
extension LogHandler {
    // Default attributed metadata log method - redacts private values using helper
    public func log(level: Logger.Level, message: Logger.Message,
                   attributedMetadata: Logger.AttributedMetadata?,
                   source: String, file: String, function: String, line: UInt) {
        let processedMetadata = attributedMetadata.flatMap(Self.attributedToPlain)
        self.log(level: level, message: message, metadata: processedMetadata,
                source: source, file: file, function: function, line: line)
    }

    // Default attributed metadata storage - uses helpers for conversion
    public var attributedMetadata: Logger.AttributedMetadata {
        get { self.metadata.mapValues(Self.plainToAttributed) }
        set { self.metadata = newValue.mapValues(Self.attributedToPlain) }
    }

    public subscript(attributedMetadataKey key: String) -> Logger.AttributedMetadataValue? {
        get {
            guard let plainValue = self[metadataKey: key] else { return nil }
            return Self.plainToAttributed(plainValue)
        }
        set {
            if let attributedValue = newValue {
                self[metadataKey: key] = Self.attributedToPlain(attributedValue)
            } else {
                self[metadataKey: key] = nil
            }
        }
    }
}
```

#### AttributedMetadata support in MetadataProvider

```swift
extension Logger.MetadataProvider {
    /// Creates a new metadata provider that returns attributed metadata.
    ///
    /// Attributed metadata providers allow you to specify privacy levels and other
    /// attributes for each metadata value. When accessed through the plain ``get()``
    /// method (for backward compatibility), private values are redacted to `"<private>"`.
    ///
    /// ### Example
    ///
    /// ```swift
    /// let provider = Logger.MetadataProvider {
    ///     [
    ///         "request-id": "\(RequestContext.current.id, privacy: .public)",
    ///         "user-id": "\(RequestContext.current.userId, privacy: .private)"
    ///     ]
    /// }
    /// ```
    ///
    /// - Parameter provideAttributed: A closure that extracts attributed metadata from the current execution context.
    /// - Returns: A metadata provider that returns attributed metadata.
    @_disfavoredOverload
    public static func init(_ provideAttributed: @escaping @Sendable () -> AttributedMetadata) -> MetadataProvider

    /// Returns attributed metadata if this is an attributed provider.
    ///
    /// Handlers supporting attributed metadata should call this first,
    /// falling back to `get()` if it returns nil.
    public func getAttributed() -> AttributedMetadata?
}
```

### API stability

- All existing APIs unchanged.
- Plain and attributed metadata APIs coexist.
- No deprecation planned.
- Adoption is optional and incremental on both application and Log Handler sides.
- Default implementation ensures existing handlers work; logging private metadata is an application concern requiring a compatible `LogHandler`.

### Future directions

Extended properties (e.g., retention policy, etc) and potential future unification of plain and attributed metadata APIs.

### Alternatives considered

1. **Key-based redaction:** Configure which keys should be treated as private rather than marking each value:

```swift
logger.privateKeys = ["user.id", "password", "email"]
logger.info("User action", metadata: [
    "user.id": "12345",  // Automatically private
    "action": "login"     // Automatically public
])
```

Advantages:
- Simpler API (no new types).
- Centralized configuration.
- Safer at scale (new sensitive fields update all logs automatically).
- Easier migration.

**Not chosen because:**

- **Privacy belongs to data, not identifiers:** The same private data might be logged under different keys ("email", "user.email", "contact"), and the same key might contain different data with different privacy requirements in different contexts. Key-based redaction creates a synchronization problem—developers must maintain a separate list of "private keys" that stays in sync with actual logging code across the codebase, with no compile-time or review-time verification.

- **Code review visibility:** With value-based privacy, reviewers see privacy decisions at the call site: `"email": user.email.private()` makes it immediately clear that data is sensitive. With key-based redaction, reviewers must cross-reference a separate configuration file, making security review significantly harder.

- **No synchronization needed:** Value-based privacy is self-contained—privacy travels with the data at the point of use. No separate configuration to maintain, no risk of configuration drift, no runtime surprises when a key is missing from the private keys list.

- **Pattern complexity:** Supporting patterns/regex adds complexity and potential performance concerns.

The current design prioritizes **explicitness and data-centric privacy** over **configuration-based simplicity**. Privacy decisions are made where data is logged, making them visible during code review and keeping privacy attributes coupled to the data they protect.

2. **Convenience methods (`.private()` and `.public()`):** Add extension methods to `String` and `MetadataValue` for creating attributed metadata:

```swift
extension String {
    public func `private`() -> Logger.AttributedMetadataValue
    public func `public`() -> Logger.AttributedMetadataValue
}

logger.info("User action", attributedMetadata: [
    "user.id": "12345".private(),
    "action": "login".public()
])
```

**Not chosen because:**

- **Consistency with existing patterns:** `Logger.Message` and `Logger.MetadataValue` already use string interpolation extensively.
- **Natural syntax:** `"\(value, privacy: .private)"` reads clearly and fits Swift's interpolation conventions.
- **Less API surface:** No need for multiple extension methods across different types.

Metadata values already support string interpolation in SwiftLog. Rather than inventing additional API surface area with new methods, we leverage the existing string interpolation infrastructure with a custom `StringInterpolation` type. This provides:

3. **Default privacy level to `.private`:** Make attributed metadata values default to `.private` privacy level when no explicit privacy parameter is provided:

```swift
logger.info("User action", attributedMetadata: [
    "user.id": "\(userId, privacy: .private)",  // Explicit private (redundant with default)
    "action": "\(action, privacy: .public)"  // Must explicitly mark as public
])
```

Advantages:
- Security-by-default: requires explicit opt-out for logging non-sensitive data.
- Safer for accidental inclusion of sensitive data.

**Not chosen because:**

Privacy should be an explicit opt-in action from the user. The current design (defaulting to `.public`) prioritizes **ease of adoption** over **security-by-default**:
- Easier adoption - less boilerplate for common non-sensitive metadata.
- Matches the mental model that "most data is safe to log".
- Lower friction for migration from plain metadata.
- Forces developers to think about privacy only for sensitive data, rather than requiring `.public` annotations everywhere.

4. **Pass all metadata to non-privacy-aware handlers:** Security risk; current design filters private data by default.

5. **Message-level privacy:** Less granular than metadata-level privacy and requires message handling changes.

6. **Privacy level handling configuration** to be an attribute of the `Logger` instead of LogHandler configuration. This would centralize the configuration across various `LogHandler` implementations. However, existing `LogHandler` already have configurations and they might want to customize the behavior even further.

7. **Handler metadata merging:** LogHandlers are responsible for merging their own `metadata` property, `metadataProvider` output, and the explicit `attributedMetadata` parameter. This is consistent with how plain metadata works - handlers control merging. Plain handler metadata and provider values should be treated as public (`.public` privacy level). Attributed metadata from the log call takes precedence.

8. **Add a thirds `.auto`/`.default` privacy attribute value:** Libraries and applications can mark a metadata value as `privacy: .default` and rely on the `LogHandler` to configure what the default is. While this might've been a solution to overcome default `.public` values for all the attributed metadata, in reality it is confusing from the semantic point of view. If someone wants to mark something as `.default`, because this _might_ be sensitive, then it should be marked as `.private` or not logged at all. If something does not need to be marked as `.private`, then it is `.public`. A custom `LogHandler` with an allow list of metadata keys/messages/modules can be used as an escape hatch in case the application does not trust its dependencies.
