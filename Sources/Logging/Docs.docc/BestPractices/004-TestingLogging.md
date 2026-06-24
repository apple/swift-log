# 004: Testing code that logs

Assert on what your code logged by capturing entries in memory, instead of bootstrapping
a process-wide backend.

## Overview

The `InMemoryLogging` product ships an `InMemoryLogHandler` that collects every emitted
record into an array you can inspect with `#expect`. Keep it local to each test: a handler
created in the test has no shared state, so tests stay isolated and parallel-safe — unlike
``LoggingSystem/bootstrap(_:)``, which sets one process-wide backend and traps if called
twice.

Add the product to your test target:

```swift
.product(name: "InMemoryLogging", package: "swift-log")
```

### Capture logs from a logger you pass in

When the code under test accepts a `Logger` (see <doc:003-AcceptingLoggers>), back it with
an `InMemoryLogHandler` and assert on `entries`:

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

Each `Entry` exposes `level`, `message`, `metadata`, and `error`, and is `Equatable`. The
handler defaults to ``Logger/Level/info``; set `handler.logLevel = .trace` before use to
capture lower levels (not via `withLogger(logLevel:)`, which is overwritten when you also
pass `handler`).

### Capture logs from code that reads `Logger.current`

When the code reads the task-local ``Logger/current`` instead of taking a parameter, bind
an `InMemoryLogHandler` for the scope with ``withLogger(logLevel:handler:metadata:_:)``. The
handler shares its storage by reference, so the copy you hold sees what was logged:

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
