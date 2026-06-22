# 003: Logger propagation in libraries

Propagate caller context by accepting a `Logger` parameter or reading the task-local
``Logger/current`` — never by constructing your own logger.

## Overview

Libraries should obtain a `Logger` in one of two ways: accept one through a method or
initializer parameter, or read ``Logger/current`` from the task-local. Both approaches
preserve the caller's metadata, log level, and handler choice. Constructing a logger
inside a library — via ``Logger/init(label:)`` — takes those choices away from the
application and breaks metadata propagation.

### Motivation

The application controls logging: which backend, which log level, which metadata
travels with each request. Libraries that participate in this picture obtain a logger
the application has set up, rather than constructing their own from scratch. This
ensures correlation IDs and other contextual metadata flow through the entire call
stack, and gives the application a single place to redirect or filter all log output.

Two propagation mechanisms are available, and they coexist. Choose the explicit
parameter when the library's API already accepts a `Logger` (or it's natural to add
one) — the call site stays declarative about what gets logged where. Choose the
task-local when adding a `logger:` parameter would pollute an API that otherwise has
no logging concern in its signature. Application code drives the task-local binding;
library code reads it.

### Example

#### Recommended: Accept logger through method parameters

```swift
// ✅ Good: Pass the logger through method parameters.
struct RequestProcessor {
    func processRequest(_ request: HTTPRequest, logger: Logger) async throws -> HTTPResponse {
        // Add structured metadata that every log statement should contain.
        var logger = logger
        logger[metadataKey: "request.method"] = "\(request.method)"
        logger[metadataKey: "request.path"] = "\(request.path)"
        logger[metadataKey: "request.id"] = "\(request.id)"

        logger.debug("Processing request")

        // Pass the logger down to maintain metadata context.
        let validatedData = try validateRequest(request, logger: logger)
        let result = try await executeBusinessLogic(validatedData, logger: logger)

        logger.debug("Request processed successfully")
        return result
    }

    private func validateRequest(_ request: HTTPRequest, logger: Logger) throws -> ValidatedRequest {
        logger.debug("Validating request parameters")
        return ValidatedRequest(request)
    }

    private func executeBusinessLogic(_ data: ValidatedRequest, logger: Logger) async throws -> HTTPResponse {
        logger.debug("Executing business logic")
        let dbResult = try await databaseService.query(data.query, logger: logger)
        logger.debug("Business logic completed")
        return HTTPResponse(data: dbResult)
    }
}
```

#### Recommended: Read ``Logger/current`` from the task-local

When there is no `logger:` parameter in the API, read the
task-local. The application's accumulated metadata (`request.id`, etc.) flows in
automatically without an explicit hand-off.

```swift
// ✅ Good: Library reads Logger.current; caller scopes context via withLogger.
public struct AnalyticsClient {
    public func track(_ event: String) {
        Logger.current.info("event", metadata: ["event.name": "\(event)"])
    }
}

// Application binds at @main and scopes per-request metadata.
@main
struct MyServer {
    static func main() async throws {
        let logger = Logger(label: "my-server")
        try await withLogger(logger) { _ in
            try await runServices()
        }
    }
}

func handleRequest(_ req: HTTPRequest) async throws {
    try await withLogger(mergingMetadata: ["request.id": "\(req.id)"]) { _ in
        AnalyticsClient().track("request.received")    // sees request.id automatically
    }
}
```

For per-statement metadata, pass it via the `metadata:` parameter on the log call:

```swift
Logger.current.info("step", metadata: ["step.name": "validate"])
```

For a few back-to-back lines, take a local copy and stamp metadata there — also no
propagation:

```swift
var local = Logger.current
local[metadataKey: "step.name"] = "validate"
local.info("entering")
local.info("done")
```

#### Alternative: Accept logger through initializer for long-lived components

```swift
// ⚠️ Acceptable: Logger through initializer for long-lived components
final class BackgroundJobProcessor {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func run() async {
        // Execute some long running work
        logger.debug("Update about long running work")
        // Execute some more long running work
    }
}
```

#### Avoid: Libraries creating their own loggers

Constructing ``Logger/init(label:)`` inside a library takes control over the handler, log
level, and base metadata away from the application. The application cannot redirect,
filter, or silence the library's output.

```swift
// ❌ Bad: Library creates its own logger — loses caller's context.
final class MyLibrary {
    private let logger = Logger(label: "MyLibrary")
}
```

``Logger/init(label:)`` is for the application — typically at `@main` paired with `.withLogger()`.
Library code, including internal application modules, should not construct loggers.
If they do, setting up the global factory with ``LoggingSystem/bootstrap(_:)`` allows
enforcing a specific factory on all the loggers constructed in the process. This
does not necessary need to be the same factory as was used to create the task-local
logger.

#### Avoid: Relying on ``Logger/current`` across non-Task boundaries

``Logger/current`` is backed by a `TaskLocal` and propagates through Swift's structured
concurrency model only. Callbacks invoked on non-Task threads — GCD blocks,
`URLSession` completion handlers, delegate methods dispatched onto specific queues,
`NotificationCenter` observers, C-API callbacks — see the *default* fallback logger,
not the bound one. Metadata bound by the calling `Task` is invisible inside those
callbacks.

```swift
// ❌ Bad: completion handler runs without the Task context; Logger.current is the fallback.
try await withLogger(mergingMetadata: ["request.id": "r1"]) { _ in
    URLSession.shared.dataTask(with: req) { data, _, _ in
        Logger.current.info("response")    // empty-label fallback, no request.id
    }.resume()
}
```

For libraries with async completion-handler APIs, accept an explicit `Logger` parameter.
If capturing and rebinding across the boundary is the only option:

```swift
// ✅ Good: capture before the boundary, rebind on the other side.
try await withLogger(mergingMetadata: ["request.id": "r1"]) { _ in
    let captured = Logger.current
    URLSession.shared.dataTask(with: req) { data, _, _ in
        withLogger(captured) { logger in
            logger.info("response")    // request.id preserved
        }
    }.resume()
}
```
