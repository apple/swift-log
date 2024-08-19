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

## Proposed Solution

A global function to bootstrap the test log handler:

```swift
TestingLogHandler.bootstrap()
```

A way to create a new "container" which will capture all log messages that match
a filter. Note that multiple concurrent "container"s need to collect duplicate
log messages, since tests may be ran in parallel.

To create a new "container" we can have a function that takes a filter parameter
and returns the new log container:

```swift
let container = TestingLogHandler.container { logMessage in
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

In order to make filtering easier, the `LogMessage` struct contains a `match`
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

In order to make debugging easier, the `LogMessage` struct will implement
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
