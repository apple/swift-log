# SLG-0005: Task-local logger with automatic metadata propagation

Accumulate structured logging metadata across async call stacks using task-local storage.

## Overview

- Proposal: SLG-0005
- Author(s): [Vladimir Kukushkin](https://github.com/kukushechkin)
- Status: **Awaiting Review**
- Issue: [apple/swift-log#261](https://github.com/apple/swift-log/issues/261)
- Implementation: [apple/swift-log#414](https://github.com/apple/swift-log/pull/414)

### Introduction

This proposal adds task-local logger storage to enable progressive metadata accumulation without explicit logger parameters. It focuses on solving metadata propagation challenges in applications and libraries.

### Motivation

Modern Swift applications face two primary challenges when trying to maintain rich, contextual logging with accumulated metadata.

#### Problem 1: Metadata propagation throughout the application flow

Applications need to accumulate structured metadata as execution flows through layers:

```swift
// Layer 1: HTTP handler adds request context
func handleHTTPRequest(_ request: HTTPRequest, logger: Logger) async throws {
    var logger = logger
    logger[metadataKey: "request.id"] = "\(request.id)"
    try await processBusinessLogic(request, logger: logger)
}

// Layer 2: Business logic adds user context
func processBusinessLogic(_ request: HTTPRequest, logger: Logger) async throws {
    let user = try await authenticate(request, logger: logger)
    var logger = logger
    logger[metadataKey: "user.id"] = "\(user.id)"
    try await accessDatabase(user, logger: logger)
}

// Layer 3: Database layer wants request.id, user.id, AND table context
func accessDatabase(_ user: User, logger: Logger) async throws {
    var logger = logger
    logger[metadataKey: "table"] = "users"
    logger.info("Query")
}
```

Every layer must accept a logger parameter, mutate it to add metadata, and pass it to the next layer. This is verbose and error-prone.

#### Problem 2: Library APIs polluted by logging or lost metadata context

Libraries face a dilemma with three unsatisfying options:

**Option A: Pollute public APIs**

```swift
public struct DatabaseClient {
    public func query(_ sql: String, logger: Logger) async throws -> [Row] {
        var logger = logger
        logger[metadataKey: "sql"] = "\(sql)"
        logger.debug("Query")
        return try await performQuery(sql, logger: logger)
    }

    private func performQuery(_ sql: String, logger: Logger) async throws -> [Row] {
        var logger = logger
        logger[metadataKey: "step"] = "validation"
        try await checkFraudRules(logger: logger)
    }
}
```

**Option B: Create ad-hoc loggers and lose context**

```swift
public struct DatabaseClient {
    public func query(_ sql: String) async throws -> [Row] {
        let logger = Logger(label: "database")
        logger.debug("Query", metadata: ["sql": "\(sql)"])
        // Lost: request.id, user.id, trace.id, etc.
        return try await performQuery(sql)
    }
}
```

**Option C: Don't log at all**

```swift
public struct DatabaseClient {
    public func query(_ sql: String) async throws -> [Row] {
        // No observability into library behavior
        return try await performQuery(sql)
    }
}
```

### Proposed solution

Use Swift's `@TaskLocal` storage to automatically propagate logger with accumulated metadata:

```swift
// Application code – no logger parameters needed
func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
    try await Logger.withCurrent(mergingMetadata: ["request.id": "\(request.id)"]) { logger in
        logger.info("Handling request")
        let user = try await authenticate(request)  // No logger parameter
        return try await processRequest(request, user: user)
    }
}

func authenticate(_ request: HTTPRequest) async throws -> User {
    Logger.current.debug("Authenticating")  // Has request.id automatically!
}
```

**Library code - clean APIs, full context:**

```swift
public struct DatabaseClient {
    // Public API has no logger parameter
    public func query(_ sql: String) async throws -> [Row] {
        // Logs with ALL accumulated parent metadata (request.id, user.id, etc.)
        Logger.current.debug("Query", metadata: ["sql": "\(sql)"])
        return try await performQuery(sql)
    }

    private func performQuery(_ sql: String) async throws -> [Row] {
        // Internal functions also have full context
        Logger.current.trace("Opening connection")
        // ...
    }
}
```

**Progressive metadata accumulation:**

```swift
Logger.withCurrent(mergingMetadata: ["request.id": "\(request.id)"]) { _ in
    // All code here has request.id
    // ...
    Logger.withCurrent(mergingMetadata: ["user.id": "\(user.id)"]) { _ in
        // All code here has BOTH request.id AND user.id
        // ...
        Logger.withCurrent(mergingMetadata: ["operation": "payment"]) { _ in
            // All code here has request.id, user.id, AND operation
            // ...
            Logger.current.info("Processing")  // All metadata automatically included
        }
    }
}
```

Child tasks inherit parent context automatically through Swift's structured concurrency. Context is task-local and multiple
concurrent operations do not conflict over a global state.

### Detailed design

**Public APIs:**

```swift
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Logger {
    /// The current task-local logger.
    ///
    /// This property provides direct access to the logger stored in task-local storage.
    /// Use this when you need quick access to the logger.
    ///
    /// If no task-local logger has been set up, this returns the globally bootstrapped logger
    /// with the label "task-local-fallback" and emits a warning (once per process) to help with adoption.
    /// Use ``Logger/withCurrent(changingLabel:changingHandler:changingLogLevel:mergingMetadata:changingMetadataProvider:_:)`` to properly initialize the task-local logger.
    ///
    /// > Tip: For performance-critical code with many log calls, consider extracting the logger once
    /// > instead of accessing ``Logger/current`` repeatedly:
    /// > ```swift
    /// > // Instead of this (multiple task-local lookups):
    /// > for item in items {
    /// >     Logger.current.debug("Processing", metadata: ["id": "\(item.id)"])
    /// > }
    /// >
    /// > // Do this (single lookup, then use extracted logger):
    /// > let logger = Logger.current
    /// > for item in items {
    /// >     logger.debug("Processing", metadata: ["id": "\(item.id)"])
    /// > }
    /// > ```
    ///
    /// > Important: Task-local values are **not** inherited by detached tasks created with `Task.detached`.
    /// > If you need logger context in a detached task, capture the logger explicitly.
    public static var current: Logger { get }

    /// Modify or initialize the task-local logger with optional overrides.
    ///
    /// This method allows you to modify the current task-local logger or create a new one
    /// by specifying any combination of label, handler, log level, metadata, and metadata provider.
    /// Only the specified parameters will be modified; nil parameters leave the current values unchanged.
    ///
    /// > Important: Task-local values are **not** inherited by detached tasks created with `Task.detached`.
    /// > If you need logger context in a detached task, capture the logger explicitly or use structured
    /// > concurrency (`async let`, `withTaskGroup`, etc.) instead.
    ///
    /// Example:
    /// ```swift
    /// // Initialize task-local logger at application entry point
    /// Logger.withCurrent(
    ///     changingLabel: "request-handler",
    ///     changingHandler: myHandler,
    ///     changingLogLevel: .info
    /// ) { logger in
    ///     logger.info("Request started")
    ///     // All subsequent code has access to this logger via Logger.current
    /// }
    ///
    /// // Add metadata to existing task-local logger
    /// Logger.withCurrent(mergingMetadata: ["request.id": "123"]) { logger in
    ///     logger.info("Processing request")
    /// }
    ///
    /// // Change log level in a scope
    /// Logger.withCurrent(changingLogLevel: .debug) { logger in
    ///     logger.debug("Detailed debugging info")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - changingLabel: Optional label for the logger. If provided, `changingHandler` must also be provided.
    ///   - changingHandler: Optional log handler. If provided, uses this handler for the logger.
    ///   - changingLogLevel: Optional log level. If provided, sets this log level on the logger.
    ///   - mergingMetadata: Optional metadata to merge with the current logger's metadata.
    ///   - changingMetadataProvider: Optional metadata provider to set on the logger.
    ///   - body: The closure to execute with the modified task-local logger.
    /// - Returns: The value returned by the closure.
    public static func withCurrent<Return, Failure: Error>(
        changingLabel: String? = nil,
        changingHandler: (any LogHandler)? = nil,
        changingLogLevel: Logger.Level? = nil,
        mergingMetadata: Metadata? = nil,
        changingMetadataProvider: MetadataProvider? = nil,
        _ body: (Logger) throws(Failure) -> Return
    ) rethrows -> Return

    /// Modify or initialize the task-local logger with optional overrides (async version).
    ///
    /// This method allows you to modify the current task-local logger or create a new one
    /// by specifying any combination of label, handler, log level, metadata, and metadata provider.
    /// Only the specified parameters will be modified; nil parameters leave the current values unchanged.
    ///
    /// > Important: Task-local values are **not** inherited by detached tasks created with `Task.detached`.
    /// > If you need logger context in a detached task, capture the logger explicitly or use structured
    /// > concurrency (`async let`, `withTaskGroup`, etc.) instead.
    ///
    /// Example:
    /// ```swift
    /// // Initialize task-local logger at application entry point
    /// await Logger.withCurrent(
    ///     changingLabel: "request-handler",
    ///     changingHandler: myHandler,
    ///     changingLogLevel: .info
    /// ) { logger in
    ///     logger.info("Request started")
    ///     await processRequest()
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - changingLabel: Optional label for the logger. If provided, `changingHandler` must also be provided.
    ///   - changingHandler: Optional log handler. If provided, uses this handler for the logger.
    ///   - changingLogLevel: Optional log level. If provided, sets this log level on the logger.
    ///   - mergingMetadata: Optional metadata to merge with the current logger's metadata.
    ///   - changingMetadataProvider: Optional metadata provider to set on the logger.
    ///   - body: The async closure to execute with the modified task-local logger.
    /// - Returns: The value returned by the closure.
    public static func withCurrent<Return, Failure: Error>(
        changingLabel: String? = nil,
        changingHandler: (any LogHandler)? = nil,
        changingLogLevel: Logger.Level? = nil,
        mergingMetadata: Metadata? = nil,
        changingMetadataProvider: MetadataProvider? = nil,
        _ body: (Logger) async throws(Failure) -> Return
    ) async rethrows -> Return

    /// Override the task-local logger with a specific logger instance.
    ///
    /// This method is specifically for crossing boundaries from explicit logger usage to task-local usage.
    /// It completely replaces the current task-local logger with the provided logger.
    ///
    /// > Important: Task-local values are **not** inherited by detached tasks created with `Task.detached`.
    /// > If you need logger context in a detached task, capture the logger explicitly or use structured
    /// > concurrency (`async let`, `withTaskGroup`, etc.) instead.
    ///
    /// Example:
    /// ```swift
    /// // You have an explicit logger being passed around
    /// func handleRequest(logger: Logger) {
    ///     Logger.withCurrent(overridingLogger: logger) { _ in
    ///         // Now all nested code can use Logger.current
    ///         processRequest()
    ///     }
    /// }
    ///
    /// func processRequest() {
    ///     Logger.current.info("Processing")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - overridingLogger: The logger to set as the task-local logger.
    ///   - body: The closure to execute with the overriding task-local logger.
    /// - Returns: The value returned by the closure.
    @discardableResult
    public static func withCurrent<Return, Failure: Error>(
        overridingLogger: Logger,
        _ body: (Logger) throws(Failure) -> Return
    ) rethrows -> Return

    /// Override the task-local logger with a specific logger instance (async version).
    ///
    /// This method is specifically for crossing boundaries from explicit logger usage to task-local usage.
    /// It completely replaces the current task-local logger with the provided logger.
    ///
    /// > Important: Task-local values are **not** inherited by detached tasks created with `Task.detached`.
    /// > If you need logger context in a detached task, capture the logger explicitly or use structured
    /// > concurrency (`async let`, `withTaskGroup`, etc.) instead.
    ///
    /// Example:
    /// ```swift
    /// // You have an explicit logger being passed around
    /// func handleRequest(logger: Logger) async {
    ///     await Logger.withCurrent(overridingLogger: logger) { _ in
    ///         // Now all nested code can use Logger.current
    ///         await processRequest()
    ///     }
    /// }
    ///
    /// func processRequest() async {
    ///     Logger.current.info("Processing")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - overridingLogger: The logger to set as the task-local logger.
    ///   - body: The async closure to execute with the overriding task-local logger.
    /// - Returns: The value returned by the closure.
    @discardableResult
    public static func withCurrent<Return, Failure: Error>(
        overridingLogger: Logger,
        _ body: (Logger) async throws(Failure) -> Return
    ) async rethrows -> Return
}

### Fallback behavior when task-local logger is not configured

When `Logger.current` or `Logger.withCurrent()` is accessed without prior task-local logger setup, the system provides a helpful fallback to ease adoption:

1. **Fallback to global bootstrap**: Returns a logger created using the globally bootstrapped handler (via `LoggingSystem.bootstrap()`) with the label `"task-local-fallback"`.

2. **One-time warning**: Emits a warning to stderr on first access (once per process):
   ```
   warning: Logger.current accessed without task-local context.
   Using globally bootstrapped logger as fallback.
   For proper task-local logging, use Logger.withCurrent() to set up the logging context.
   ```

3. **Graceful degradation**: Applications continue to work even without explicit task-local setup, making incremental adoption easier.

4. **A path for global bootstrapping deprecation**: If initialized explicitly, task-local logger does not require global boostrapping.

**Example migration path:**

```swift
// Phase 1: Existing code with global bootstrap continues working
LoggingSystem.bootstrap(StreamLogHandler.standardError)

// Library code immediately works (with warning)
func libraryFunction() {
    Logger.current.info("Works immediately")  // Uses fallback, warns once
}

// Phase 2: Gradually add task-local context at entry points
func main() {
    Logger.withCurrent(
        changingHandler: StreamLogHandler.standardError(label: "app")
    ) { logger in
        libraryFunction()  // Now uses proper task-local context, no warning
    }
}
```

This design allows library authors to adopt `Logger.current` immediately while application developers can add proper task-local context incrementally at their convenience.

### Performance considerations

Task-local storage access has runtime overhead compared to explicit parameter passing:

1. **`Logger.current`** - Performs task-local lookup on each access.
2. **`Logger.withCurrent { logger in }`** - Single lookup with closure-captured logger.

**When to use each?**

- Use `Logger.current` for occasional logging where convenience matters most.
- Use `Logger.withCurrent { }` in performance-sensitive code with many log calls.
- Use explicit parameter passing in tight loops if profiling identifies task-local access as a bottleneck.

### API stability

Purely additive. No changes to existing `Logger` users or `LogHandler` implementations. Users must adopt the new task-local APIs to benefit. Existing ad-hoc loggers will keep losing parent metadata.

### Future directions

None currently planned. The API provides complete control over the task-local logger through the flexible `withCurrent` method.

### Alternatives considered

#### Task-local metadata dictionary instead of task-local logger

An alternative approach would make only the metadata dictionary task-local:

```swift
// Hypothetical alternative API
Logger.withTaskLocalMetadata(["request.id": "\(request.id)"]) {
    // All Logger instances automatically merge task-local metadata
    let logger = Logger(label: "database")  // Ad-hoc logger now gets parent metadata!
    logger.info("Query")  // Has request.id from task-local storage
}
```

This would allow ad-hoc logger creation while preserving parent metadata.

**Why this was rejected:**

1. **Semantically confusing**: Decouples logger from its metadata. `Logger(label: "foo")` would have different metadata depending on whether it's inside a task-local scope, making logger metadata unpredictable.

2. **Changes default behavior**: All existing logger creation suddenly merges invisible metadata, which is a breaking semantic change affecting all code.

3. **Overlaps with swift-distributed-tracing**: Swift's distributed tracing already provides task-local propagation for tracing contexts. Having two competing task-local metadata systems creates confusion about which to use.

The proposed solution is more explicit: library authors consciously adopt `Logger.current`, making the behavior clear and intentional.

#### Public `taskLocalLogger` property

Rejected—exposes implementation detail, more verbose.
