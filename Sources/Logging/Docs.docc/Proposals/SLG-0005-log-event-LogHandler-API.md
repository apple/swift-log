# SLG-0005: `LogEvent`-based `LogHandler` API

Replace the flat-parameter `log(level:message:metadata:source:file:function:line:)` method on `LogHandler` with
`log(event: LogEvent)`, enabling forward-compatible evolution of the `LogHandler` interface without breaking existing
handler implementations.

## Overview

- Proposal: SLG-0005
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **Ready for Implementation**
- Issue: [apple/swift-log#421](https://github.com/apple/swift-log/issues/421)
- Implementation:
    - [apple/swift-log#423](https://github.com/apple/swift-log/pull/423)
- Related links:
    - [Lightweight proposals process description](https://github.com/apple/swift-log/blob/main/Sources/Logging/Docs.docc/Proposals/Proposals.md)
    - [SLG-0003: Standardized Error Metadata via Logger Convenience](https://github.com/apple/swift-log/blob/main/Sources/Logging/Docs.docc/Proposals/SLG-0003.md)

### Introduction

Introduce `LogEvent` that bundles all log-statement data, and replace the flat-parameter
`log(level:message:metadata:source:file:function:line:)` method on `LogHandler` with `log(event: LogEvent)`.

### Motivation

The `LogHandler` protocol currently requires implementing a single method with seven parameters:

```swift
func log(
    level: Logger.Level,
    message: Logger.Message,
    metadata: Logger.Metadata?,
    source: String,
    file: String,
    function: String,
    line: UInt
)
```

Every time a new piece of data needs to be forwarded from a log call site to the handler — an error, or a richer metadata type — the only options are:

- **Add a new parameter to the existing method.** This is a source-breaking change: every existing `LogHandler`
  implementation across the entire Swift ecosystem must be updated simultaneously.
- **Add a new `Logger` overload.** This requires 2 parallel APIs to coexist until the old one can be safely deprecated.

### Proposed solution

Introduce `LogEvent`, a `struct` that carries all the data associated with a single log statement. `LogEvent` is
a handler-side type: it is constructed by `Logger._log` and passed to `LogHandler`. The public `Logger` call-site
API — `logger.info(...)`, `logger.log(level:...)` and so on — is unchanged.

The `LogHandler` protocol gains a new required method `log(event: LogEvent)`, while the old flat-parameter method
is deprecated.

For existing handlers, a default implementation of `log(event:)` forwards to the old method, so no code changes
are required to keep existing implementations working. Handlers that want to take advantage of new fields added to
`LogEvent` in future proposals implement `log(event:)`.

### Detailed design

#### New `LogEvent` type

A new top-level `struct` in the `Logging` module:

```swift
public struct LogEvent: Sendable {
    public var level: Logger.Level
    public var message: Logger.Message
    private var _metadata: Logger.Metadata?
    public var metadata: Logger.Metadata? {
        get { self._metadata }
        set { self._metadata = newValue }
    }
    public var source: String
    public var file: String
    public var function: String
    public var line: UInt

    public init(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    )
}
```

#### Updated `LogHandler` protocol

```swift
public protocol LogHandler: _SwiftLogSendableLogHandler {

    /// The library calls this method when a log handler must emit a log message.
    ///
    /// There is no need for the `LogHandler` to check if the level is above or below the configured `logLevel`
    /// as `Logger` already performed this check and determined that a message should be logged.
    ///
    /// - Parameter event: The log event containing the level, message, metadata, and source location.
    func log(event: LogEvent)

    /// Please do _not_ implement this method when you create a `LogHandler` implementation.
    /// Implement ``log(event:)`` instead.
    ///
    /// - Parameters:
    ///   - level: The log level of the message.
    ///   - message: The message to log. To obtain a `String` representation call `message.description`.
    ///   - metadata: The metadata associated to this log message.
    ///   - source: The source where the log message originated, for example the logging module.
    ///   - file: The file this log message originates from.
    ///   - function: The function this log message originates from.
    ///   - line: The line this log message originates from.
    @available(*, deprecated, renamed: "log(event:)")
    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    )
}
```

#### Default implementation

The default for `log(event:)` forwards all event fields to the old flat-parameter method,
preserving the behavior of existing handlers with no source changes required:

```swift
extension LogHandler {
    public func log(event: LogEvent) {
        self.log(
            level: event.level,
            message: event.message,
            metadata: event.metadata,
            source: event.source,
            file: event.file,
            function: event.function,
            line: event.line
        )
    }
}
```

### API stability

**For existing `Logger` users:** No changes. All existing call sites continue to compile and behave identically.

**For existing `LogHandler` implementations:** Implementations of
`log(level:message:metadata:source:file:function:line:)` continue to work without any source changes. The
default implementation of `log(event:)` forwards to the old method.

### Future directions

Future proposals can add new fields to `LogEvent` with sensible defaults — a richer metadata
type, or an attached `Error` (as a follow-up for [SLG-0003 proposal](https://forums.swift.org/t/proposal-slg-0003-standardized-error-metadata-via-logger-convenience/84518/39)) —
without touching the `LogHandler` protocol and without requiring any changes to
existing handler implementations. This is the primary motivation for this proposal.

The [SLG-0004 proposal](https://github.com/apple/swift-log/pull/416) introduces an `AttributedMetadata` type that wraps
`Logger.Metadata` with additional context. Adding it to `LogEvent` as a new optional field would be
source-compatible, and the existing `metadata` field could become a computed property that projects from
`attributedMetadata` when present, keeping old handlers fully functional without modification.

### Alternatives considered

#### Adding parameters with default values to the existing method

Adding new parameters with default values avoids introducing a new method, but still constitutes a
source-breaking change: every existing `LogHandler` implementation that implements the method explicitly
must add the new parameter. The whole point of this proposal is to avoid that pattern indefinitely.
