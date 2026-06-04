# SLG-0006: Task-local logger with automatic metadata propagation

Accumulate structured logging metadata across async call stacks using task-local storage.

## Overview

- Proposal: SLG-0006
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **Awaiting Review**
- Issue: [apple/swift-log#261](https://github.com/apple/swift-log/issues/261)
- Implementation: [apple/swift-log#459](https://github.com/apple/swift-log/pull/459)
- Feature flag: none
- Related links:
  - [Lightweight proposals process description](https://github.com/apple/swift-log/blob/main/Sources/Logging/Docs.docc/Proposals/Proposals.md)

### Introduction

This proposal adds task-local logger storage so that metadata can accumulate across async
call stacks without threading a `Logger` through every function signature.

### Motivation

Metadata propagation requires threading a logger through every layer. Every function on
the path from request ingress to the bottom of the call stack has to accept, mutate, and
forward a `Logger`:

```swift
func handleHTTPRequest(_ request: HTTPRequest, logger: Logger) async throws {
    var logger = logger
    logger[metadataKey: "request.id"] = "\(request.id)"
    try await processBusinessLogic(request, logger: logger)
}
```

Libraries must choose between polluting their public API with a `logger:` parameter and
losing all the caller's context. There is no third option today.

### Proposed solution

Use Swift's `@TaskLocal` to propagate a logger with accumulated metadata. The caller sets up
a scope, callees read `Logger.current`:

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
A library reads `Logger.current` directly — the caller's accumulated metadata flows in
automatically without a `logger:` parameter:

```swift
public struct DatabaseClient {
    public static func query(_ sql: String) async throws -> [Row] {
        Logger.current.debug("Executing", metadata: ["sql": "\(sql)"])
        return try await performQuery(sql)
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

Returns the logger bound by the nearest enclosing `withLogger` scope. If none is active,
returns the process-wide unbound default: a `Logger(label: "")` constructed via
`LoggingSystem.factory` the first time the task-local is touched.

```swift
extension Logger {
    /// The current task-local logger.
    ///
    /// Returns the logger bound by the nearest enclosing ``withLogger(_:_:)`` scope.
    /// If none is active, returns the process-wide unbound default: a
    /// `Logger(label: "")` cached from the first time the task-local is touched.
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
`@TaskLocal`'s own runtime availability.

#### `withLogger` free functions

Three overload groups, each with sync and async variants. The closure receives the logger
as a parameter to avoid repeated task-local lookups inside the closure body.

**Bind a specific logger:**

```swift
/// Runs `operation` with `logger` bound to the task-local context.
///
/// Code called within `operation` can read the logger via ``Logger/current`` without an
/// explicit parameter. Binding a different logger with this overload **replaces** the
/// current task-local logger; any metadata accumulated by an outer
/// ``withLogger(mergingMetadata:_:)`` or
/// ``withLogger(logLevel:handler:metadata:_:)`` scope is not carried over.
///
/// This overload is the application-bootstrap binding mechanism: pass a `Logger`
/// constructed via ``Logger/init(label:)`` at your application entry point. Because
/// ``Logger/init(label:)`` consults ``LoggingSystem/factory``, the constructed `Logger`
/// only carries a useful handler once ``LoggingSystem/bootstrap(_:)`` has been called.
/// For mid-call-tree backend swaps that should work without bootstrap (tests, scoped
/// routing), use ``withLogger(logLevel:handler:metadata:_:)`` instead — it modifies the
/// current logger's handler in place without constructing a new one.
///
/// let logger = Logger(label: "app")
/// await withLogger(logger) { logger in
///     logger.info("Application started")
///     await handleRequests()  // reads Logger.current
/// }
///
/// - Parameters:
///   - logger: The logger to bind for the duration of `operation`.
///   - operation: The closure to run with `logger` bound. Receives `logger` as a
///     parameter so the body does not need to re-read ``Logger/current``.
/// - Returns: The value returned by `operation`.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func withLogger<Result, Failure: Error>(
    _ logger: Logger,
    _ operation: (Logger) throws(Failure) -> Result
) throws(Failure) -> Result

/// Runs `operation` with `logger` bound to the task-local context. Async variant of
/// ``withLogger(_:_:)``; see that function for full semantics.
///
/// - Parameters:
///   - logger: The logger to bind for the duration of `operation`.
///   - operation: The async closure to run with `logger` bound. Receives `logger` as
///     a parameter so the body does not need to re-read ``Logger/current``.
/// - Returns: The value returned by `operation`.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
nonisolated(nonsending)
public func withLogger<Result, Failure: Error>(
    _ logger: Logger,
    _ operation: nonisolated(nonsending) (Logger) async throws(Failure) -> Result
) async throws(Failure) -> Result
```

**Append metadata for a scope:**

```swift
/// Runs `operation` with a copy of ``Logger/current`` that has `metadata` **layered on
/// top of** the inherited base metadata. Keys present in `metadata` override existing
/// keys with the same name; other inherited metadata is preserved. Handler and log
/// level are unchanged.
///
/// Use this overload at request boundaries and any point where context should
/// accumulate. Nested ``withLogger(mergingMetadata:_:)`` scopes layer on top of each
/// other.
///
/// withLogger(mergingMetadata: ["request.id": "\(request.id)"]) { logger in
///     logger.info("Handling request")
///     withLogger(mergingMetadata: ["user.id": "\(user.id)"]) { logger in
///         logger.info("Authenticated")  // sees both request.id and user.id
///     }
/// }
///
/// - Parameters:
///   - metadata: Metadata keys merged onto the inherited base metadata for the scope.
///     Keys override existing values with the same name.
///   - operation: The closure to run with the merged logger bound. Receives the
///     merged logger as a parameter.
/// - Returns: The value returned by `operation`.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func withLogger<Result, Failure: Error>(
    mergingMetadata metadata: @autoclosure () -> Logger.Metadata,
    _ operation: (Logger) throws(Failure) -> Result
) throws(Failure) -> Result

/// Runs `operation` with a copy of ``Logger/current`` that has `metadata` layered on
/// top of the inherited base metadata. Async variant of ``withLogger(mergingMetadata:_:)``;
/// see that function for full semantics.
///
/// - Parameters:
///   - metadata: Metadata keys merged onto the inherited base metadata for the scope.
///     Keys override existing values with the same name.
///   - operation: The async closure to run with the merged logger bound. Receives the
///     merged logger as a parameter.
/// - Returns: The value returned by `operation`.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
nonisolated(nonsending)
public func withLogger<Result, Failure: Error>(
    mergingMetadata metadata: @autoclosure () -> Logger.Metadata,
    _ operation: nonisolated(nonsending) (Logger) async throws(Failure) -> Result
) async throws(Failure) -> Result
```

**Replace aspects of the current logger:**

```swift
/// Runs `operation` with a copy of ``Logger/current`` whose aspects are **replaced** by
/// the provided arguments. `nil` parameters leave the corresponding aspect unchanged.
///
/// Unlike ``withLogger(mergingMetadata:_:)``, which layers metadata on top of the
/// inherited base, this overload **replaces** the base metadata when `metadata` is
/// non-nil. Pass `metadata: [:]` to wipe the inherited metadata entirely.
///
/// With no arguments, this overload re-binds ``Logger/current`` unchanged — a convenient
/// way to extract it into a local variable for repeated use inside the closure.
///
/// withLogger(mergingMetadata: ["request.id": "\(request.id)"]) { _ in
///     // Background job: start a scope with metadata unrelated to the request.
///     withLogger(metadata: ["job.id": "\(job.id)"]) { logger in
///         logger.info("running")  // metadata: job.id only — request.id wiped
///     }
/// }
///
/// - Parameters:
///   - logLevel: When non-nil, replaces the current log level for the scope. When
///     `nil`, the inherited log level is preserved.
///   - handler: When non-nil, replaces the current logger's handler for the scope.
///     Useful in tests to route logs through an `InMemoryLogHandler` or similar while
///     keeping the caller's label. When `nil`, the inherited handler is preserved.
///   - metadata: When non-nil, replaces the handler's base metadata dictionary for
///     the scope. Pass `[:]` to erase inherited metadata; pass a fresh dictionary to
///     start a scope from a known state. When `nil`, the inherited base metadata is
///     preserved.
///   - operation: The closure to run with the modified logger bound. Receives the
///     modified logger as a parameter.
/// - Returns: The value returned by `operation`.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func withLogger<Result, Failure: Error>(
    logLevel: Logger.Level? = nil,
    handler: (any LogHandler)? = nil,
    metadata: @autoclosure () -> Logger.Metadata? = nil,
    _ operation: (Logger) throws(Failure) -> Result
) throws(Failure) -> Result

/// Runs `operation` with a copy of ``Logger/current`` whose aspects are replaced by
/// the provided arguments. Async variant of
/// ``withLogger(logLevel:handler:metadata:_:)``; see that function for full semantics.
///
/// - Parameters:
///   - logLevel: When non-nil, replaces the current log level for the scope. When
///     `nil`, the inherited log level is preserved.
///   - handler: When non-nil, replaces the current logger's handler for the scope.
///     Useful in tests to route logs through an `InMemoryLogHandler` or similar while
///     keeping the caller's label. When `nil`, the inherited handler is preserved.
///   - metadata: When non-nil, replaces the handler's base metadata dictionary for
///     the scope. Pass `[:]` to erase inherited metadata; pass a fresh dictionary to
///     start a scope from a known state. When `nil`, the inherited base metadata is
///     preserved.
///   - operation: The async closure to run with the modified logger bound. Receives
///     the modified logger as a parameter.
/// - Returns: The value returned by `operation`.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
nonisolated(nonsending)
public func withLogger<Result, Failure: Error>(
    logLevel: Logger.Level? = nil,
    handler: (any LogHandler)? = nil,
    metadata: @autoclosure () -> Logger.Metadata? = nil,
    _ operation: nonisolated(nonsending) (Logger) async throws(Failure) -> Result
) async throws(Failure) -> Result
```

Calling `withLogger { logger in ... }` with no arguments is the single-lookup idiom for
extracting `Logger.current` into a local variable for repeated use inside the closure —
analogous to `withSpan { span in ... }` in `swift-distributed-tracing`.


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

**ABI and resilience.** The `withLogger` overloads, `Logger.current`, and the task-local
storage are intentionally **not** `@inlinable` / `@usableFromInline` in this proposal.
The bodies are still evolving — future iterations are expected to factor parts of the
implementation through value-level `Logger.withMetadata(...)` methods (see Future
directions) — and committing to `@inlinable` now would freeze the current shape into
ABI. The trade-off is one non-inlined function call per `withLogger` scope entry, which
is negligible relative to the structured-concurrency machinery already involved.
`@inlinable` annotations can be added in a non-breaking follow-up once the shape is
settled and benchmarks justify the ABI commitment.

**Source compatibility caveat.** The name `withLogger` is added at the top-level namespace.
Codebases that previously defined their own free `withLogger` function may need to
fully-qualify calls (`Logging.withLogger(...)`) or rename their own.

### Future directions

- **`Logger.withMetadata(merging:) -> Logger` and `Logger.withMetadata(replacing:) -> Logger`
  value-level instance methods.** Construct a derived `Logger` value (not a scope) with
  metadata layered onto or wholly replacing the receiver's metadata. The scope-level
  equivalents (`withLogger(mergingMetadata:)` and `withLogger(metadata:)`) ship in this
  proposal; the value-level forms are useful for per-statement metadata that should not
  propagate via the task-local — for example, a library that wants to stamp a key on its
  own log lines without pushing it onto `Logger.current` (avoiding leakage into downstream
  callees).

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
accumulates *local* per-scope logger configuration (log level, handler, and application
metadata like `request.id`) that is meaningful only within a single process. The
task-local logger also carries more than metadata — it holds the `LogHandler`, log
level, and label, none of which belong in a context intended for cross-process propagation.
The existing `MetadataProvider` already bridges the two systems at log-emission time:
handlers read trace/span IDs from `ServiceContext` without swift-log depending on it.

#### No closure parameter — require `Logger.current` inside the closure

`withLogger(logger) { ... }` without a parameter, reading `Logger.current` inside. Rejected
because passing the logger avoids repeated task-local lookups, follows the `withSpan`
convention, and makes it obvious at the call site which logger is in use.

#### Not propagating metadata across module boundaries by default

Expose a public `TaskLocal<Logger>` extension surface so that each module can declare
its own scoped logger and stay structurally isolated from other modules — pushes on one
module's task-local would be invisible to another's reads. Rejected for two reasons.

First, the public surface cost: `@TaskLocal`-declared task-locals require the `$logger`
projection syntax for the scope methods (`MyApp.$logger.withMetadata(merging: …) { … }`),
which is unfamiliar and easy to get wrong; alternatively, exposing `TaskLocal<Logger>`
typed properties would leak a stdlib type into the swift-log surface that we'd rather
keep internal. Hiding the task-local behind `Logger.current` and the `withLogger` free
functions trades isolation for a cleaner API.

Second, the leak case is disciplinable. The only way library code propagates its own
metadata downstream through `Logger.current` is by calling `withLogger(mergingMetadata:)`
or `withLogger(metadata:)`. The documented contract is that those overloads are
application-side APIs: libraries read `Logger.current` and use per-statement `metadata:`
or a local copy for their own context; they do not push. Per-module isolation would make
the leak impossible *by construction* even when discipline fails, but it would also
fragment cross-cutting metadata propagation (`request.id` accumulated at the application
layer would not appear on library log lines without an explicit bridge from one
task-local to another) — which is the propagation we most want by default.

If structural isolation turns out to matter for specific use cases, the public
`TaskLocal<Logger>` extension surface can be added as a non-breaking follow-up.
