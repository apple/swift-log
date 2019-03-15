# swift-log

A Logging API package for Swift.

## Great, what's the tl;dr

If you have a cross-platform (for example Linux & macOS) Swift application or library and you would like to log, we think targeting this logging API package is a great idea. Below you'll find all you need to know to get started.

#### Add a dependency

To depend on the logging API package, you just need to declare your dependency in your `Package.swift`:

```swift
// it's super early days here so we haven't tagged a version yet, but will soon
.package(url: "https://github.com/apple/swift-log.git", .branch("master")),
```

and to your application/library target, add `"Logging"` to your `dependencies`.

#### Let's log

```swift
// 1) let's import the logging API package
import Logging

// 2) we need to create a logger, the label works similarly to a DispatchQueue label
let logger = Logger(label: "com.example.BestExampleApp.main")

// 3) we're now ready to use it
logger.info("Hello World!")
```

#### Output

```
2019-03-13T15:46:38+0000 info: Hello World!
```

## What is an API package?

Glad you asked. We believe that for the Swift on Server ecosystem it's crucial to have a logging API that can be adopted by anybody so a multitude of libraries from different parties can all log to a shared destination. More concretely this means that we believe all the log messages from all libraries end up in the same file, database, Elastic Stack/Splunk instance, or whatever you may choose.

In the real-world however there are so many opinions over how exactly a logging system should behave, what a log message should be formatted like, and where/how it should be persisted. We think it's not feasible to wait for one logging package to support everything that a specific deployment needs whilst still being easy enough to use and remain performant. That's why we decided to cut the problem in half:

1. a logging API
2. a logging backend implementation

This package only provides the logging API itself and therefore `swift-log` is a 'logging API package'. `swift-log` (using `LoggingSystem.bootstrap`) can be configured to choose any compatible logging backend implementation. This way packages can adopt the API and the _application_ can choose any compatible logging backend implementation without requiring any changes from any of the libraries.

Just for completeness sake: This API package does actually include an overly simplistic and non-configurable logging backend implementation which simply writes all log messages to `stdout`. The reason to include this overly simplistic logging backend implementation is to improve the first-time usage experience. Let's assume you start a project and try out `swift-log` for the first time, it's just a whole lot better to see something you logged appear on `stdout` in a simplistic format rather than nothing happening at all. For any real-world application we advise to configure another logging backend implementation that logs in the style you like.

## The core concepts

### Loggers

`Logger`s are used to emit log messages and therefore the most important type in `swift-log`. Using `Logger`s is very straightforward. Most commonly, they are used to emit log messages in a certain log level. For example

```swift
// logging an informational message
logger.info("Hello World!")

// ouch, something went wrong
logger.error("Houston, we have a problem: \(problem)")
```

### Log levels

The following log levels are supported:

 - `debug`
 - `info`
 - `notice`
 - `warning`
 - `error`
 - `critical`
 - `alert`
 - `emergency`

The log level of a given logger can be changed but the change will only affect the very logger you changed it on.


### Logging metadata

Logging metadata is metadata that can be attached to loggers to add information that is crucial when debugging a problem. In servers, the usual example is attaching a request UUID to a logger that will then be present on all log messages logged with that logger. Example:

```swift
var logger = logger
logger[metadataKey: "request-uuid"] = "\(UUID())"
logger.info("hello world")
```

will print

```
2019-03-13T18:30:02+0000 info: request-uuid=F8633013-3DD8-481C-9256-B296E43443ED hello world
```

with the default logging backend implementation that ships with `swift-log`. Needless to say the format is fully defined by the logging backend you choose.

## On the implementation of a logging backend (a `LogHandler`)

Note: If you don't want to implement a custom logging backend, everything is this section is probably not very relevant, so please feel free to skip.

To become a compatible logging backend that all `swift-log` consumers can use, you need to do two things: 1) Implement a type (usually a `struct`) that implements `LogHandler`, a protocol provided by `swift-log` and 2) instruct `swift-log` to use your logging backend implementation.

A `LogHandler` or logging backend implementation is anything that conforms to the following protocol

```swift
public protocol LogHandler {
    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: StaticString, function: StaticString, line: UInt)

    subscript(metadataKey _: String) -> Logger.Metadata.Value? { get set }

    var metadata: Logger.Metadata { get set }

    var logLevel: Logger.Level { get set }
}
```

Instructing `swift-log` to use your logging backend as the one the whole application (including all libraries) should use is very simple:

    LoggingSystem.bootstrap(MyLogHandler.init)

### Implementation considerations

`LogHandler`s control most parts of the logging system:

#### Under control of a `LogHandler`

##### Configuration

`LogHandler`s control the two crucial pieces of `Logger` configuration, namely

- log level (`logger.logLevel` property)
- logging metadata (`logger[metadataKey:]` and `logger.metadata`)

For the system to work however it is important that `LogHandler` treat the configuration as _value types_. This means that `LogHandler`s should be `struct`s and a change in log level or logging metadata should only affect the very `LogHandler` it was changed on.

However, in special cases, it is acceptable that a `LogHandler` provide some global log level override that may affect all `LogHandler`s created.

##### Emitting
- emitting the log message itself

### Not under control of `LogHandler`s

`LogHandler`s do not control if a message should be logged or not. `Logger` will only invoke the `log` function of a `LogHandler` if `Logger` determines that a log message should be emitted given the configured log level.

## Design

This logging API was designed with the contributors to the Swift on Server community and approved by the [SSWG (Swift Server Work Group)](https://swift.org/server/) to the 'sandbox level' of the SSWG's [incubation process](https://github.com/swift-server/sswg/blob/master/process/incubation.md).

- [pitch](https://forums.swift.org/t/logging/16027), [discussion](https://forums.swift.org/t/discussion-server-logging-api/18834), [feedback](https://forums.swift.org/t/feedback-server-logging-api-with-revisions/19375)
- [log levels](https://forums.swift.org/t/logging-levels-for-swifts-server-side-logging-apis-and-new-os-log-apis/20365)
