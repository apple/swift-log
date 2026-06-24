# 004: Testing code that logs

Validate what you code logs by capturing entries in memory rather than bootstrapping a process-wide backend.

## Overview

Import and use `InMemoryLogging`, which provides an `InMemoryLogHandler` that collects every emitted record into an array you can inspect.
Keep a handler you create local to each test.
Each handler that you create in a test has no shared state, so the test stays isolated is safe to run on parallel with other tests.
Don't use ``LoggingSystem/bootstrap(_:)`` in a test, it sets one process-wide backend and traps if called twice.

Add the product to your test target:

```swift
.product(name: "InMemoryLogging", package: "swift-log")
```

### Capture logs from a logger you pass in

When the code under test accepts a `Logger` (see <doc:003-AcceptingLoggers>), back it with
an `InMemoryLogHandler` and validate the results on `entries`.
The following code illustrates how to set up and validate a handler using `InMemoryLogging` to check the expected results:

```swift
import InMemoryLogging
import Logging
import Testing

@Test
func stampsRequestID() {
    let handler = InMemoryLogHandler()
    let logger = Logger(label: "test", factory: { _ in handler })

    RequestProcessor().handle(id: "42", logger: logger)

    #expect(handler.entries.count == 1)
    #expect(handler.entries[0].message == "request received")
    #expect(handler.entries[0].metadata["request.id"] == "42")
}
```

Each `Entry` is equatable and exposes `level`, `message`, `metadata`, and `error`.
The handler log level defaults to ``Logger/Level/info``; set `handler.logLevel = .trace` before you use it to
capture lower levels.

### Capture logs from code that reads `Logger.current`

When the code you want to test reads the task-local ``Logger/current`` instead of taking a parameter, bind an `InMemoryLogHandler` for the scope of that by using ``withLogger(logLevel:handler:metadata:_:)``.
The handler shares its storage by reference, so the copy you hold sees what was logged:

```swift
import InMemoryLogging
import Logging
import Testing

@Test
func tracksEvent() {
    let handler = InMemoryLogHandler()
    withLogger(handler: handler) { _ in
        AnalyticsClient().track("signup")  // calls Logger.current.info(...)
    }

    #expect(handler.entries.count == 1)
    #expect(handler.entries[0].metadata["event.name"] == "signup")
}
```
