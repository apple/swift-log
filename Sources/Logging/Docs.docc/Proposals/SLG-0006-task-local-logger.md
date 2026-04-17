# SLG-0006: Task-local logger with automatic metadata propagation

Accumulate structured logging metadata across async call stacks using task-local storage.

## Overview

- Proposal: SLG-0006
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **Awaiting Review**
- Issue: [apple/swift-log#261](https://github.com/apple/swift-log/issues/261)
- Implementation: [apple/swift-log#414](https://github.com/apple/swift-log/pull/414)
- Feature flag: none
- Related links:
  - [Lightweight proposals process description](https://github.com/apple/swift-log/blob/main/Sources/Logging/Docs.docc/Proposals/Proposals.md)

### Introduction

This proposal adds task-local logger storage to enable progressive metadata accumulation without explicit logger
parameters.

### Motivation

#### Problem 1: Metadata propagation requires threading loggers through every layer

```swift
func handleHTTPRequest(_ request: HTTPRequest, logger: Logger) async throws {
    var logger = logger
    logger[metadataKey: "request.id"] = "\(request.id)"
    try await processBusinessLogic(request, logger: logger)
}

func processBusinessLogic(_ request: HTTPRequest, logger: Logger) async throws {
    let user = try await authenticate(request, logger: logger)
    var logger = logger
    logger[metadataKey: "user.id"] = "\(user.id)"
    try await accessDatabase(user, logger: logger)
}

func accessDatabase(_ user: User, logger: Logger) async throws {
    var logger = logger
    logger[metadataKey: "table"] = "users"
    logger.info("Query")
}
```

Every layer must accept, mutate, and forward a logger parameter. This is verbose and error-prone.

#### Problem 2: Libraries must choose between API pollution and lost context

```swift
// Option A: Pollute public APIs with logger parameter
public func query(_ sql: String, logger: Logger) async throws -> [Row] { ... }

// Option B: Create ad-hoc loggers, lose all parent metadata
public func query(_ sql: String) async throws -> [Row] {
    let logger = Logger(label: "database")  // Lost: request.id, user.id, trace.id
    logger.debug("Query")
    ...
}

// Option C: Do not log at all
```

### Proposed solution

Use Swift's `@TaskLocal` storage to propagate a logger with accumulated metadata:

```swift
func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
    try await withLogger(mergingMetadata: ["request.id": "\(request.id)"]) { logger in
        logger.info("Handling request")
        let user = try await authenticate(request)  // No logger parameter needed
        return try await processRequest(request, user: user)
    }
}

func authenticate(_ request: HTTPRequest) async throws -> User {
    Logger.current.debug("Authenticating")  // Has request.id automatically
}
```

Libraries get clean APIs with full context:

```swift
public struct DatabaseClient {
    public func query(_ sql: String) async throws -> [Row] {
        Logger.current.debug("Query", metadata: ["sql": "\(sql)"])  // Has all parent metadata
        return try await performQuery(sql)
    }
}
```

Metadata accumulates through nesting:

```swift
withLogger(mergingMetadata: ["request.id": "\(request.id)"]) { _ in
    withLogger(mergingMetadata: ["user.id": "\(user.id)"]) { _ in
        withLogger(mergingMetadata: ["operation": "payment"]) { logger in
            logger.info("Processing")  // Has request.id, user.id, AND operation
        }
    }
}
```

Child tasks inherit parent context automatically through structured concurrency. `Task.detached` does not inherit
context — capture the logger explicitly if needed.

### Detailed design

#### `Logger.current`

Returns the current task-local logger, or a fallback logger if none is set.

```swift
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Logger {
    /// The current task-local logger.
    ///
    /// This property provides direct access to the logger stored in task-local storage.
    /// Use this when you need quick access to the logger without a closure.
    ///
    /// If no task-local logger has been set up, this returns the globally bootstrapped logger
    /// with the label "task-local-fallback" and emits a warning (once per process) to help with adoption.
    /// Use ``withLogger(_:_:)-6n3m5`` to properly initialize the task-local logger.
    ///
    /// > Tip: For performance-critical code with many log calls, consider extracting the logger once
    /// > instead of accessing ``Logger/current`` repeatedly:
    /// > ```swift
    /// > let logger = Logger.current
    /// > for item in items {
    /// >     logger.debug("Processing", metadata: ["id": "\(item.id)"])
    /// > }
    /// > ```
    ///
    /// > Important: Task-local values are **not** inherited by detached tasks created with `Task.detached`.
    /// > If you need logger context in a detached task, capture the logger explicitly.
    @inlinable
    public static var current: Logger { get }
}
```

#### `withLogger` free functions

Four free functions: two overload groups, each with sync and async variants. The closure always receives the logger
as a parameter for convenience and to avoid repeated task-local lookups inside the closure body.

> Note: The API uses `rethrows` instead of `throws(Failure)` because the underlying `TaskLocal.withValue` API uses
> untyped throws. This is a known deviation from the project preference against `rethrows` in public API, forced by
> the standard library limitation. Once `TaskLocal.withValue` gains typed throws support, these signatures can be
> updated to `throws(Failure)` without breaking source compatibility, since `rethrows` is more restrictive.
>
> The async variants do not constrain `Result: Sendable` for the same reason.

**Bind a specific logger:**

```swift
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)

/// Runs the given closure with a logger bound to the task-local context.
///
/// This is the primary way to set up a task-local logger. All code within the closure can access the logger
/// via ``Logger/current`` without explicit parameter passing.
///
/// - Parameters:
///   - logger: The logger to bind to the task-local context.
///   - operation: The closure to run with the logger bound.
/// - Returns: The value returned by the closure.
@inlinable
public func withLogger<Result>(
    _ logger: Logger,
    _ operation: (Logger) throws -> Result
) rethrows -> Result

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)

/// Runs the given async closure with a logger bound to the task-local context.
///
/// Async variant of the synchronous ``withLogger(_:_:)-6n3m5``.
///
/// - Parameters:
///   - logger: The logger to bind to the task-local context.
///   - operation: The async closure to run with the logger bound.
/// - Returns: The value returned by the closure.
@inlinable
nonisolated(nonsending)
public func withLogger<Result>(
    _ logger: Logger,
    _ operation: nonisolated(nonsending) (Logger) async throws -> Result
) async rethrows -> Result
```

**Modify the current task-local logger:**

```swift
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)

/// Runs the given closure with a modified task-local logger.
///
/// This function modifies the current task-local logger by specifying any combination of log level,
/// metadata, and metadata provider. Only the specified parameters modify the current logger; `nil`
/// parameters leave the current values unchanged.
///
/// - Parameters:
///   - logLevel: Optional log level. If provided, sets this log level on the logger.
///   - mergingMetadata: Optional metadata to merge with the current logger's metadata.
///   - metadataProvider: Optional metadata provider to set on the logger.
///   - operation: The closure to run with the modified task-local logger.
/// - Returns: The value returned by the closure.
@inlinable
public func withLogger<Result>(
    logLevel: Logger.Level? = nil,
    mergingMetadata: Logger.Metadata? = nil,
    metadataProvider: Logger.MetadataProvider? = nil,
    _ operation: (Logger) throws -> Result
) rethrows -> Result

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)

/// Runs the given async closure with a modified task-local logger.
///
/// Async variant. See the synchronous
/// ``withLogger(logLevel:mergingMetadata:metadataProvider:_:)-3urd2`` for detailed documentation.
///
/// - Parameters:
///   - logLevel: Optional log level. If provided, sets this log level on the logger.
///   - mergingMetadata: Optional metadata to merge with the current logger's metadata.
///   - metadataProvider: Optional metadata provider to set on the logger.
///   - operation: The async closure to run with the modified task-local logger.
/// - Returns: The value returned by the closure.
@inlinable
nonisolated(nonsending)
public func withLogger<Result>(
    logLevel: Logger.Level? = nil,
    mergingMetadata: Logger.Metadata? = nil,
    metadataProvider: Logger.MetadataProvider? = nil,
    _ operation: nonisolated(nonsending) (Logger) async throws -> Result
) async rethrows -> Result
```

To create a new logger with a specific handler, construct it and pass it to `withLogger`:

```swift
let logger = Logger(label: "app", handler: myHandler)
withLogger(logger) { logger in
    logger.info("Using custom handler")
}
```

#### Fallback behavior

When `Logger.current` is accessed without prior setup:

1. Returns a logger created from the globally bootstrapped handler with label `"task-local-fallback"`. The fallback
   logger is not cached so that changes to `LoggingSystem.bootstrap()` are always reflected.
2. Emits a `.warning`-level log through that logger on first access (once per process). The warning is thread-safe.
3. Applications continue to work, making incremental adoption easy.

```swift
// Phase 1: Library code works immediately with global bootstrap (warns once)
LoggingSystem.bootstrap(StreamLogHandler.standardError)
Logger.current.info("Works")

// Phase 2: Add task-local context at entry points
let logger = Logger(label: "app", handler: StreamLogHandler.standardError(label: "app"))
withLogger(logger) { logger in
    // No more fallback warning, full metadata propagation
}
```

#### Performance considerations

- `Logger.current` performs a task-local lookup on each access.
- `withLogger { logger in }` does a single lookup; use the closure's `logger` parameter for repeated logging.
- Use explicit parameter passing in tight loops if profiling identifies task-local access as a bottleneck.

### API stability

**For existing `Logger` users:** No changes. All existing call sites continue to compile and behave identically.
The new API is purely additive.

**For existing `LogHandler` implementations:** No changes required. No new protocol requirements are added, no
default implementations are introduced that handlers need to be aware of. Task-local loggers use the same
`LogHandler` interface. `MaxLogLevel` traits from SLG-0002 work correctly with task-local loggers since
`Logger.current` returns a standard `Logger` instance.

**Platform requirements**: macOS 10.15+, iOS 13.0+, watchOS 6.0+, tvOS 13.0+ (requires `@TaskLocal`).

### Future directions

None currently planned.

### Alternatives considered

#### Task-local metadata dictionary instead of task-local logger

Make only the metadata dictionary task-local, so ad-hoc `Logger(label:)` calls automatically merge it.

Rejected because it changes default behavior for all existing logger creation (breaking semantic change), decouples
logger from its metadata in a confusing way, and overlaps with `swift-distributed-tracing`'s context propagation.

#### Public `taskLocalLogger` property

Rejected — exposes implementation detail, more verbose than `Logger.current`.

#### Static methods on `Logger` instead of free functions

`Logger.withCurrent(...)` instead of `withLogger(...)`.

Rejected — inconsistent with `withSpan(...)` from `swift-distributed-tracing` and `withMetricsFactory(...)` from
`swift-metrics`. Free functions follow the established ecosystem convention.

#### Use `ServiceContext` from swift-distributed-tracing instead of a new task-local

Store metadata in the existing `ServiceContext` that `swift-distributed-tracing` propagates, rather than introducing
a second `@TaskLocal`.

Rejected because:

- `ServiceContext` is server-specific infrastructure; `swift-log` is a general-purpose API for all platforms (iOS,
  macOS, embedded, CLI tools), not just server workloads.
- Adding this to `swift-log` directly avoids requiring a separate package dependency, simplifying usage and
  discoverability for the majority of adopters who do not use distributed tracing.
- `swift-log` is standalone with no dependency on `swift-distributed-tracing`. Coupling them would create a circular
  dependency.
- The task-local logger carries more than metadata — it holds the `LogHandler`, log level, label, and metadata
  provider.
- `ServiceContext` values are set once at boundaries; logger metadata accumulates progressively through nested scopes.
- The existing `MetadataProvider` already bridges the two: loggers can read trace IDs from `ServiceContext` at
  log-emission time without coupling the packages at the propagation level.

#### No closure parameter — require `Logger.current` inside the closure

Instead of `withLogger(logger) { logger in ... }`, use `withLogger(logger) { ... }` and require accessing
`Logger.current` inside the closure body.

Rejected because:

- Passing the logger to the closure avoids repeated task-local lookups in code that logs multiple times.
- It follows the `withSpan` pattern from `swift-distributed-tracing`, which also passes the span to the closure.
- The closure parameter makes it clear which logger is being used, improving readability.
