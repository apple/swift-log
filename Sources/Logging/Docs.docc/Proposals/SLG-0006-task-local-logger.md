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

This proposal adds task-local logger storage so that metadata can accumulate across async
call stacks without threading a `Logger` through every function signature.

### Motivation

**Metadata propagation requires threading a logger through every layer.** Every function on
the path from request ingress to the bottom of the call stack has to accept, mutate, and
forward a `Logger`:

```swift
func handleHTTPRequest(_ request: HTTPRequest, logger: Logger) async throws {
    var logger = logger
    logger[metadataKey: "request.id"] = "\(request.id)"
    try await processBusinessLogic(request, logger: logger)
}
```

**Libraries must choose between polluting their public API with a `logger:` parameter and
losing all the caller's context.** There is no third option today.

### Proposed solution

Use Swift's `@TaskLocal` to propagate a logger with accumulated metadata. The caller sets up
a scope, callees read `Logger.current` freely:

```swift
func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
    try await withLogger(mergingMetadata: ["request.id": "\(request.id)"]) { logger in
        logger.info("Handling request")  // Has request.id automatically
        return try await processRequest(request)  // no logger parameter needed
    }
}

func processRequest(_ request: HTTPRequest) async throws -> User {
    Logger.current.debug("Processing...")  // Has request.id automatically
    DatabaseClient.query(request.sqlQuery)
}
```

Libraries keep their APIs clean while still emitting logs with the caller's full context.
A library that wants to log under its own label (so operators can grep by module) can
rebrand the current logger without losing accumulated metadata:

```swift
public struct DatabaseClient {
    public static func query(_ sql: String) async throws -> [Row] {
        try await withLogger(label: "postgres-client", mergingMetadata: ["sql": "\(sql)"]) { logger in
            logger.debug("Executing query")  // label = "postgres-client", metadata includes request.id and sql
            return try await performQuery(sql)
        }
    }
}
```

**Wiring it up with swift-service-lifecycle.** At the application entry point, bind the
bootstrapped logger once; service lifecycle propagates the task-local through the
`ServiceGroup` and into every task spawned from its `run()`:

```swift
@main
struct MyServer {
    static func main() async throws {
        let logger = Logger(label: "my-server")
        try await withLogger(logger) { _ in
            let serviceGroup = ServiceGroup(
                configuration: .init(
                    services: [HTTPServer(), BackgroundWorker()],
                    gracefulShutdownSignals: [.sigint],
                    cancellationSignals: [.sigterm],
                    logger: logger
                )
            )
            try await serviceGroup.run()
        }
    }
}
```

Metadata accumulates through nesting and task-local values propagate through structured
concurrency (`async let`, `withTaskGroup`, child `Task {}`). `Task.detached` does not
inherit context — capture the logger explicitly if needed.

### Detailed design

#### `Logger.current`

Returns the logger bound by the nearest enclosing `withLogger` scope. If none has been set
up, returns a fallback logger: the globally bootstrapped handler if
`LoggingSystem.bootstrap` has been called, otherwise a silent `SwiftLogNoOpLogHandler`.

The no-op branch returns a cached logger and emits a **one-time warning on stderr** the
first time it is taken so a user who forgot to call `LoggingSystem.bootstrap` (or to wrap
their entry point in `withLogger`) doesn't see logs silently disappear with no diagnostic.

The bootstrapped branch invokes `LoggingSystem.factory` on every access. `Logger.current` is
not meant to be a hot path outside of a `withLogger` scope — callers should wrap their
entry point in `withLogger(_:_:)` and use the closure's `logger` parameter or a local `let`
binding for repeated logging.

```swift
extension Logger {
    /// The current task-local logger.
    ///
    /// Returns the logger bound by the nearest enclosing ``withLogger(_:_:)`` scope.
    /// If none has been set up, returns a fallback logger: the globally bootstrapped
    /// handler if ``LoggingSystem/bootstrap(_:)`` has been called, otherwise a silent
    /// ``SwiftLogNoOpLogHandler``.
    ///
    /// Task-local values propagate through structured concurrency (`async let`,
    /// `withTaskGroup`, child `Task {}`) but are **not** inherited by `Task.detached`.
    /// Capture the logger explicitly across detached boundaries.
    ///
    /// For many log calls in a tight scope, prefer extracting the logger once —
    /// either `let logger = Logger.current` or the closure's `logger` parameter
    /// from `withLogger { logger in ... }` — instead of re-reading the task-local
    /// on every call.
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public static var current: Logger { get }
}
```

The per-symbol `@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)` mirrors
`@TaskLocal`'s own runtime availability. `Package.swift` intentionally does **not**
declare a `platforms:` clause, so each symbol gates itself rather than raising the
floor for the whole package.

#### `withLogger` free functions

Two overload groups, each with sync and async variants. The closure receives the logger as
a parameter to avoid repeated task-local lookups inside the closure body.

**Bind a specific logger:**

```swift
/// Runs `operation` with `logger` bound to the task-local context.
///
/// Code called within `operation` can read the logger via ``Logger/current`` without an
/// explicit parameter. Binding a different logger with this overload **replaces** the
/// current task-local logger; any metadata accumulated by an outer
/// ``withLogger(logLevel:mergingMetadata:_:)`` scope is not carried over. Use the modifying
/// overload to layer context instead.
///
/// ```swift
/// let logger = Logger(label: "app")
/// await withLogger(logger) { logger in
///     logger.info("Application started")
///     await handleRequests()  // reads Logger.current
/// }
/// ```
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public func withLogger<Result>(
    _ logger: Logger,
    _ operation: (Logger) throws -> Result
) rethrows -> Result

/// Async variant of ``withLogger(_:_:)``. See that function for semantics.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
nonisolated(nonsending)
public func withLogger<Result>(
    _ logger: Logger,
    _ operation: nonisolated(nonsending) (Logger) async throws -> Result
) async rethrows -> Result
```

**Modify the current task-local logger:**

```swift
/// Runs `operation` with a modified copy of ``Logger/current`` bound to the task-local
/// context. `nil` parameters leave the corresponding aspect unchanged; nested scopes
/// accumulate metadata.
///
/// - `label` — rebrands the current logger with the given label while keeping the existing
///   handler, metadata, and log level. Useful for library code that wants to emit logs
///   under its own label (e.g. `"postgres-client"`) while still inheriting the caller's
///   accumulated metadata.
/// - `handler` — replaces the current logger's handler for the scope. Primarily useful in
///   tests to route logs through an `InMemoryLogHandler` or similar, while keeping the
///   caller's label and accumulated metadata.
/// - `logLevel` — replaces the current log level.
/// - `mergingMetadata` — merges into the handler's base metadata; keys present in
///   `mergingMetadata` override existing values for the same keys.
///
/// With no arguments, this overload re-binds ``Logger/current`` unchanged — a convenient
/// way to extract it into a local variable for repeated use inside the closure.
///
/// ```swift
/// withLogger(mergingMetadata: ["request.id": "\(request.id)"]) { logger in
///     logger.info("Handling request")
///     withLogger(mergingMetadata: ["user.id": "\(user.id)"]) { logger in
///         logger.info("Authenticated")  // sees both request.id and user.id
///     }
/// }
/// ```
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public func withLogger<Result>(
    label: String? = nil,
    handler: (any LogHandler)? = nil,
    logLevel: Logger.Level? = nil,
    mergingMetadata: Logger.Metadata? = nil,
    _ operation: (Logger) throws -> Result
) rethrows -> Result

/// Async variant of ``withLogger(label:handler:logLevel:mergingMetadata:_:)``. See that
/// function for semantics.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
nonisolated(nonsending)
public func withLogger<Result>(
    label: String? = nil,
    handler: (any LogHandler)? = nil,
    logLevel: Logger.Level? = nil,
    mergingMetadata: Logger.Metadata? = nil,
    _ operation: nonisolated(nonsending) (Logger) async throws -> Result
) async rethrows -> Result
```

Calling `withLogger { logger in ... }` with no arguments is the single-lookup idiom for
extracting `Logger.current` into a local variable for repeated use inside the closure —
analogous to `withSpan { span in ... }` in `swift-distributed-tracing`.

> Note: `rethrows` (not `throws(Failure)`) and the absence of a `Sendable` constraint on
> `Result` mirror the shape of `TaskLocal.withValue` in the current standard library.

#### Relationship to `MetadataProvider`

Metadata merged via `withLogger(mergingMetadata:)` is written into the handler's base
metadata on the per-task logger copy. If a handler has a `MetadataProvider` attached — for
example a bootstrapped OpenTelemetry provider that reads `trace.id` from `ServiceContext` —
the provider still runs at log-emission time and follows the handler's conventional merge
order (base < provider < per-statement).

This proposal does **not** add a `metadataProvider:` parameter to the modifying overload.
Application code that wants to swap the provider for a scope should construct a new `Logger`
and use the binding overload. Keeping the two concerns separate avoids shipping the
replace-vs-compose question as part of the core API.

### API stability

**For existing `Logger` users:** no changes. The new API is purely additive.

**For existing `LogHandler` implementations:** no changes required. Task-local loggers use
the same `LogHandler` interface; no new protocol requirements are added.

**Package platform minimums.** `Package.swift` intentionally does not gain a `platforms:`
clause. Each new symbol carries `@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)`
to match `@TaskLocal`'s runtime availability. Callers targeting older deployment versions
keep working; they just can't call the task-local API.

**Source compatibility caveat.** The name `withLogger` is added at the top-level namespace.
Codebases that previously defined their own free `withLogger` function may need to
fully-qualify calls (`Logging.withLogger(...)`) or rename their own.

### Future directions

None.

### Alternatives considered

#### Task-local metadata dictionary instead of task-local logger

Make only the metadata dictionary task-local, so ad-hoc `Logger(label:)` calls automatically
merge it. Rejected because it changes default behavior for all existing logger creation
(breaking semantic change) and overlaps with `swift-distributed-tracing`'s
`ServiceContext`.

#### Static methods on `Logger` instead of free functions

`Logger.withCurrent(...)` instead of `withLogger(...)`. Rejected — inconsistent with
`withSpan(...)` from `swift-distributed-tracing` and `withMetricsFactory(...)` from
`swift-metrics`. Free functions follow the established ecosystem convention.

#### Use `ServiceContext` from swift-distributed-tracing instead of a new task-local

Store metadata in the existing `ServiceContext` — propagated by `swift-service-context`,
the leaf package already designed as a shared propagation primitive — rather than
introducing a second `@TaskLocal`. Rejected because the two propagation channels serve
different use cases: `ServiceContext` carries *distributed* correlation (trace/span IDs,
baggage) that flows across process boundaries, while `withLogger(mergingMetadata:)`
accumulates *local* per-scope logger configuration (label, log level, handler, and
application metadata like `request.id`) that is meaningful only within a single process.
The task-local logger also carries more than metadata — it holds the `LogHandler`, log
level, and label, none of which belong in a context intended for cross-process propagation.
The existing `MetadataProvider` already bridges the two systems at log-emission time:
handlers read trace/span IDs from `ServiceContext` without swift-log depending on it.

#### No closure parameter — require `Logger.current` inside the closure

`withLogger(logger) { ... }` without a parameter, reading `Logger.current` inside. Rejected
because passing the logger avoids repeated task-local lookups, follows the `withSpan`
convention, and makes it obvious at the call site which logger is in use.
