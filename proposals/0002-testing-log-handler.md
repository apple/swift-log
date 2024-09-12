# Test Log Handler

Authors: [Brian Maher](https://github.com/brimworks), [Konrad 'ktoso' Malawski](https://github.com/ktoso)

## Introduction

Software operators rely on logging to provide insight into what is being done,
therefore, testing log output is an important facet.

## Motivation

A variety of implementations have cropped up organically, but having a single
test log handler to build off of will reduce the re-write churn.

### Existing Implementations

* [swift-log-testing](https://github.com/neallester/swift-log-testing)
* [swift-distributed-actors/LogCapture](https://github.com/apple/swift-distributed-actors/blob/main/Sources/DistributedActorsTestKit/LogCapture.swift)
* [swift-cluster-membership/LogCapture](https://github.com/apple/swift-cluster-membership/blob/main/Tests/SWIMTestKit/LogCapture.swift)
* [RediStack/RedisLoggingTests](https://github.com/swift-server/RediStack/blob/master/Tests/RediStackIntegrationTests/RedisLoggingTests.swift)
* [swift-log/TestLogger](https://github.com/apple/swift-log/blob/main/Tests/LoggingTests/TestLogger.swift#L52)


## Features

A testing log handler needs the following features:
* The ability to capture log entries at the start of a unit test.
* The ability to assert the captured log entries contain a matching message.
* Work correctly in the face of parallel test execution.
* Print log messages to the console if the log entry does not match a log entry
  that is being asserted.
* Bootstrap the test log handler as early as possible so we don't miss any
  `Logger()` creations which may happen during setup.

## Ideal World vs Real World

In an ideal world, all `Logger()` instances could be manually "injected" in
which case, one could use the `Logger`s `init(handler:)` constructor to inject
in the testing log handler.

The unfortunate reality of the "real world" is that many `Logger` instances have
no way to be injected, or performing that injection would be very tedious.

Therefore, the solution needs some way to work without requiring the usage of
a manually injected log handler.

## Proposed Solution

Users of the library will create assertions about future log messages. These
assertions simply last for a well defined scope. At the end of the scope, if
no log message matches the assertion, then the assertion will be deemed a
failure.

Ideally, the users of this test log handler would manually construct their
`Logger` instances to use the log handler as such:

```swift
let assertion = TestLogHandler.assertion(label: "Example", level: .debug)
let logger = Logger(label: "Example", factory: assertion.factory)
...
XCTAssertTrue(assertion.test, assertion.description)
```

However, to support situations where the person performing the log tests is
**not** in control of the creation of `Logger` instances, you can choose to
bootstrap with the `TestLogHandler` using the test frameworks `setUp` method:

```swift
class TestMyLogs: XCTestCase {
    override func setUp() {
        TestLogHandler.bootstrap() 
    }
    func testExample() {
        let logger = Logger(label: "Example")
        let assertion = TestLogHandler.assertion(label: "Example", level: .debug)
        ...
        XCTAssertTrue(assertion.test, assertion.description)
    }
}
```

The disadvantage here, is that **every** `Logger` instance is eligible for
matching the assertion verses a very specific instance of `Logger` being the only
instance which is eligible for assertion. In practice though, this shouldn't be
a problem, since it is easy to target specific `Logger` instances via the
`label`. 

Note that we bootstrapped `TestLogHandler` using the `TestLogHandler.bootstrap()`
method over manually calling `LoggingSystem.bootstrap(TestLogHandler.init)` so
that we can ensure this setup happens exactly once, and any future attempt to
bootstrap will not cause a fatal error. This way multiple test suites can all
have a `setUp()` which bootstraps the `TestLogHandler` without the `logging
system can only be initialized once per process` error.

### Why Declare Assertion And Later Perform Assertion?

In the examples so far, the assertion is created first, then "stuff" happens
which is expected to cause the assertion to pass, and finally the assertion is
tested to ensure that expectation was met.

By setting the expectation about what assertion we are searching for up front,
we can "ignore" all other log messages which do not match that assertion. These
"ignored" log messages can then be (potentially) printed to stderr, which aids
immensely in the understanding of potential failures which are being handled by
logging. For example, it isn't to uncommon to catch all exceptions and then
log them at an "error" level. If these "error" level exceptions are not printed
to stderr, then it becomes very difficult to understand various failure modes.
This is especially painful in any CI (Continuous Integration) system, where your
only hope of understanding what took place is to introspect the stderr log
messages.

### Other Use Cases

Another use-case for the `TestLogHandler` is to simply discard "noisy" log
messages. For example, when fuzz testing, it isn't to uncommon for the various
fuzzes to trigger spurious log messages that you want to just discard.

To support this use-case, you can create a "container" of log messages that
match a filter. These will not be considered "ignored" log messages and thus
will not be printed to stderr by default.

To create a new "container" we can have a function that takes a filter parameter
and returns the new log container:

```swift
let container = TestLogHandler.container { logMessage in
    // Ideally, you would be as specific as possible in your filtering!
    return logMessage.level == Logger.Level.debug &&
        logMessage.label == "Test" &&
        logMessage.message.description == "Matched"
}
// Emit a log that matches the filter:
Logger(label: "Test").debug("Matched")

// Emit a log that does NOT match the filter:
Logger(label: "Test").debug("Printed to console")

// Assert that the log message was found:
XCTAssertFalse(container.messages.isEmpty)
```

It is recommended to create a separate container for each log assertion so that
you can simply check that the messages in a container are non-empty. If you use
this pattern you also protect yourself from accidental log message matches that
occur due to a test ran in parallel. An accidental match could cause a failing
test to spuriously succeed, but it would never cause a successful test to
spuriously fail.

If a log message is emitted that does **not** match any container's filter, it
will be printed to the console in the same way as the default built-in log
handler.

In order to make filtering easier, the `CapturedLogMessage` struct contains a `match`
function that takes the following optional parameters:
* label: `String?`
* level: `Logger.Level?`
* message: `Regex<AnyRegexOutput>?`
* metadata: `[(Logger.Metadata.Element) -> Bool]`
* source: `Regex<AnyRegexOutput>?`
* file: `Regex<AnyRegexOutput>?`
* function: `String?`
* line: `UInt?`

Only if all specified parameters match will this function return true.

In order to make debugging easier, the `CapturedLogMessage` struct will implement
`CustomStringConvertible` which causes the log message to be formatted in the
default built-in log handler format.

Additionally, each field of the log message is public and can be used for
custom filtering:
* timestamp: `Date`
* label: `String`
* level: `Logger.Level`
* message: `Logger.Message` (note that this is also `CustomStringConvertible`)
* metadata: `Logger.Metadata`
* source: `String`
* file: `String`
* function: `String`
* line: `UInt`

Note that the log handler implementation must maintain "weak" pointers to all
the containers so as to avoid memory leaks.

Also note that the `LogHandler.logLevel` is **always** `.trace`, otherwise log
messages that are at to low of a level will not have a chance to be captured
due to the `if self.logLevel <= level` guard on the `Logging.log()` method.
