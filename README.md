# SwiftLog

First things first: This is the beginning of a community-driven open-source project actively seeking contributions, be it code, documentation, or ideas. Apart from contributing to `SwiftLog` itself, there's another huge gap at the moment: `SwiftLog` is an _API package_ which tries to establish a common API the ecosystem can use. To make logging really work for real-world workloads, we need `SwiftLog`-compatible _logging backends_ which then either persist the log messages in files, render them in nicer colors on the terminal, or send them over to Splunk or ELK.

What `SwiftLog` provides today can be found in the [API docs][api-docs].

## Getting started

If you have a server-side Swift application, or maybe a cross-platform (for example Linux & macOS) app/library, and you would like to log, we think targeting this logging API package is a great idea. Below you'll find all you need to know to get started.

#### Adding the dependency

`SwiftLog` is designed for Swift 5. To depend on the logging API package, you need to declare your dependency in your `Package.swift`:

```swift
.package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
```

and to your application/library target, add `"Logging"` to your `dependencies`, e.g. like this:

```swift
// Target syntax for Swift up to version 5.1
.target(name: "BestExampleApp", dependencies: ["Logging"]),

// Target for Swift 5.2
.target(name: "BestExampleApp", dependencies: [
    .product(name: "Logging", package: "swift-log")
],
```


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

#### Default `Logger` behavior

`SwiftLog` provides for very basic console logging out-of-the-box by way of `StreamLogHandler`. It is possible to switch the default output to `stderr` like so:
```swift
LoggingSystem.bootstrap(StreamLogHandler.standardError)
```

`StreamLogHandler` is primarily a convenience only and does not provide any substantial customization. Library maintainers who aim to build their own logging backends for integration and consumption should implement the `LogHandler` protocol directly as laid out in [the "On the implementation of a logging backend" section](#on-the-implementation-of-a-logging-backend-a-loghandler).

For further information, please check the [API documentation][api-docs].

<a name="backends"></a>
## Available Logging Backends For Applications

You can choose from one of the following backends to consume your logs. If you are interested in implementing one see the "Implementation considerations" section below explaining how to do so. List of existing SwiftLog API compatible libraries:

| Repository | Handler Description|
| ----------- | ----------- |
| [Kitura/HeliumLogger](https://github.com/Kitura/HeliumLogger)  |a logging backend widely used in the Kitura ecosystem |
| [ianpartridge/swift-log-**syslog**](https://github.com/ianpartridge/swift-log-syslog) | a [syslog](https://en.wikipedia.org/wiki/Syslog) backend|
| [Adorkable/swift-log-**format-and-pipe**](https://github.com/Adorkable/swift-log-format-and-pipe) | a backend that allows customization of the output format and the resulting destination |
| [chrisaljoudi/swift-log-**oslog**](https://github.com/chrisaljoudi/swift-log-oslog) | an OSLog [Unified Logging](https://developer.apple.com/documentation/os/logging) backend for use on Apple platforms. **Important Note:** we recommend using os_log directly as described [here](https://developer.apple.com/documentation/os/logging). Using os_log through swift-log using this backend will be less efficient and will also prevent specifying the privacy of the message. The backend always uses `%{public}@` as the format string and eagerly converts all string interpolations to strings.  This has two drawbacks: 1. the static components of the string interpolation would be eagerly copied by the unified logging system, which will result in loss of performance. 2. It makes all messages public, which changes the default privacy policy of os_log, and doesn't allow specifying fine-grained privacy of sections of the message.  In a separate on-going work, Swift APIs for os_log are being improved and made to align closely with swift-log APIs. References: [Unifying Logging Levels](https://forums.swift.org/t/custom-string-interpolation-and-compile-time-interpretation-applied-to-logging/18799), [Making os_log accept string interpolations using compile-time interpretation](https://forums.swift.org/t/logging-levels-for-swifts-server-side-logging-apis-and-new-os-log-apis/20365). |
| [Brainfinance/StackdriverLogging](https://github.com/Brainfinance/StackdriverLogging) | a structured JSON logging backend for use on Google Cloud Platform with the [Stackdriver logging agent](https://cloud.google.com/logging/docs/agent) |
| [DnV1eX/GoogleCloudLogging](https://github.com/DnV1eX/GoogleCloudLogging) | a client-side library for logging application events in [Google Cloud](https://console.cloud.google.com/logs) via REST API v2. |
| [vapor/console-kit](https://github.com/vapor/console-kit/) | a logger to the current terminal or stdout with stylized ([ANSI](https://en.wikipedia.org/wiki/ANSI_escape_code)) output. The default logger for all Vapor applications |
| [neallester/swift-log-testing](https://github.com/neallester/swift-log-testing) | provides access to log messages for use in assertions (within test targets) |
| [wlisac/swift-log-slack](https://github.com/wlisac/swift-log-slack)  | a logging backend that sends critical log messages to Slack |
| [NSHipster/swift-log-github-actions](https://github.com/NSHipster/swift-log-github-actions) | a logging backend that translates logging messages into [workflow commands for GitHub Actions](https://help.github.com/en/actions/reference/workflow-commands-for-github-actions). |
| [stevapple/swift-log-telegram](https://github.com/stevapple/swift-log-telegram) | a logging backend that sends log messages to any Telegram chat (Inspired by and forked from [wlisac/swift-log-slack](https://github.com/wlisac/swift-log-slack)) |
| [jagreenwood/swift-log-datadog](https://github.com/jagreenwood/swift-log-datadog)  | a logging backend which sends log messages to the [Datadog](https://www.datadoghq.com/log-management/) log management service |
| [google/SwiftLogFireCloud](https://github.com/google/swiftlogfirecloud)  | a logging backend for time series logging which pushes logs as flat files to Firebase Cloud Storage. |
| [crspybits/swift-log-file](https://github.com/crspybits/swift-log-file)  | a simple local file logger (using `Foundation` `FileManager`) |
| [sushichop/Puppy](https://github.com/sushichop/Puppy) | a logging backend that supports multiple transports(console, file, syslog, etc.) and has the feature with formatting and file log rotation |
| [luoxiu/LogDog](https://github.com/luoxiu/LogDog) | user-friendly logging with sinks and appenders |
| [ShivaHuang/swift-log-SwiftyBeaver](https://github.com/ShivaHuang/swift-log-SwiftyBeaver) | a logging backend for printing colored logging to Xcode console / file, or sending encrypted logging to [SwiftyBeaver](https://swiftybeaver.com) platform. |
| [Apodini/swift-log-elk](https://github.com/Apodini/swift-log-elk) | a logging backend that formats, caches and sends log data to [elastic/logstash](https://github.com/elastic/logstash) |
| [binaryscraping/swift-log-supabase](https://github.com/binaryscraping/swift-log-supabase) | a logging backend that sends log entries to [Supabase](https://github.com/supabase/supabase). |
| [kiliankoe/swift-log-matrix](https://swiftpackageindex.com/kiliankoe/swift-log-matrix) | a logging backend for sending logs directly to a [Matrix](https://matrix.org) room |
| [DiscordBM/DiscordLogger](https://github.com/DiscordBM/DiscordLogger) | a Discord logging implementation to send your logs over to a Discord channel in a good-looking manner and with a lot of configuration options including the ability to send only a few important log-levels such as `warning`/`error`/`critical`. |
| [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) | a fast & simple, yet powerful & flexible logging framework for macOS, iOS, tvOS and watchOS, which includes a logging backend for swift-log. |
| Your library? | [Get in touch!](https://forums.swift.org/c/server) |

## What is an API package?

Glad you asked. We believe that for the Swift on Server ecosystem, it's crucial to have a logging API that can be adopted by anybody so a multitude of libraries from different parties can all log to a shared destination. More concretely this means that we believe all the log messages from all libraries end up in the same file, database, Elastic Stack/Splunk instance, or whatever you may choose.

In the real-world however, there are so many opinions over how exactly a logging system should behave, what a log message should be formatted like, and where/how it should be persisted. We think it's not feasible to wait for one logging package to support everything that a specific deployment needs whilst still being easy enough to use and remain performant. That's why we decided to cut the problem in half:

1. a logging API
2. a logging backend implementation

This package only provides the logging API itself and therefore `SwiftLog` is a 'logging API package'. `SwiftLog` (using `LoggingSystem.bootstrap`) can be configured to choose any compatible logging backend implementation. This way packages can adopt the API and the _application_ can choose any compatible logging backend implementation without requiring any changes from any of the libraries.

Just for completeness sake: This API package does actually include an overly simplistic and non-configurable logging backend implementation which simply writes all log messages to `stdout`. The reason to include this overly simplistic logging backend implementation is to improve the first-time usage experience. Let's assume you start a project and try out `SwiftLog` for the first time, it's just a whole lot better to see something you logged appear on `stdout` in a simplistic format rather than nothing happening at all. For any real-world application, we advise configuring another logging backend implementation that logs in the style you like.

## The core concepts

### Loggers

`Logger`s are used to emit log messages and therefore the most important type in `SwiftLog`, so their use should be as simple as possible.  Most commonly, they are used to emit log messages in a certain log level. For example:

```swift
// logging an informational message
logger.info("Hello World!")

// ouch, something went wrong
logger.error("Houston, we have a problem: \(problem)")
```

### Log levels

The following log levels are supported:

 - `trace`
 - `debug`
 - `info`
 - `notice`
 - `warning`
 - `error`
 - `critical`

The log level of a given logger can be changed, but the change will only affect the specific logger you changed it on. You could say the `Logger` is a _value type_ regarding the log level.


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

with the default logging backend implementation that ships with `SwiftLog`. Needless to say, the format is fully defined by the logging backend you choose.

## On the implementation of a logging backend (a `LogHandler`)

Note: If you don't want to implement a custom logging backend, everything in this section is probably not very relevant, so please feel free to skip.

To become a compatible logging backend that all `SwiftLog` consumers can use, you need to do two things: 1) Implement a type (usually a `struct`) that implements `LogHandler`, a protocol provided by `SwiftLog` and 2) instruct `SwiftLog` to use your logging backend implementation.

A `LogHandler` or logging backend implementation is anything that conforms to the following protocol

```swift
public protocol LogHandler {
    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt)

    subscript(metadataKey _: String) -> Logger.Metadata.Value? { get set }

    var metadata: Logger.Metadata { get set }

    var logLevel: Logger.Level { get set }
}
```

Instructing `SwiftLog` to use your logging backend as the one the whole application (including all libraries) should use is very simple:

    LoggingSystem.bootstrap(MyLogHandler.init)

### Implementation considerations

`LogHandler`s control most parts of the logging system:

#### Under control of a `LogHandler`

##### Configuration

`LogHandler`s control the two crucial pieces of `Logger` configuration, namely:

- log level (`logger.logLevel` property)
- logging metadata (`logger[metadataKey:]` and `logger.metadata`)

For the system to work, however, it is important that `LogHandler` treat the configuration as _value types_. This means that `LogHandler`s should be `struct`s and a change in log level or logging metadata should only affect the very `LogHandler` it was changed on.

However, in special cases, it is acceptable that a `LogHandler` provides some global log level override that may affect all `LogHandler`s created.

##### Emitting
- emitting the log message itself

### Not under control of `LogHandler`s

`LogHandler`s do not control if a message should be logged or not. `Logger` will only invoke the `log` function of a `LogHandler` if `Logger` determines that a log message should be emitted given the configured log level.

## Source vs Label

A `Logger` carries an (immutable) `label` and each log message carries a `source` parameter (since SwiftLog 1.3.0). The `Logger`'s label
identifies the creator of the `Logger`. If you are using structured logging by preserving metadata across multiple modules, the `Logger`'s
`label` is not a good way to identify where a log message originated from as it identifies the creator of a `Logger` which is often passed
around between libraries to preserve metadata and the like.

If you want to filter all log messages originating from a certain subsystem, filter by `source` which defaults to the module that is emitting the
log message.

## Security

Please see [SECURITY.md](SECURITY.md) for SwiftLog's security process.

## Design

This logging API was designed with the contributors to the Swift on Server community and approved by the [SSWG (Swift Server Work Group)](https://swift.org/server/) to the 'sandbox level' of the SSWG's [incubation process](https://github.com/swift-server/sswg/blob/master/process/incubation.md).

- [pitch](https://forums.swift.org/t/logging/16027), [discussion](https://forums.swift.org/t/discussion-server-logging-api/18834), [feedback](https://forums.swift.org/t/feedback-server-logging-api-with-revisions/19375)
- [log levels](https://forums.swift.org/t/logging-levels-for-swifts-server-side-logging-apis-and-new-os-log-apis/20365)

[api-docs]: https://apple.github.io/swift-log/docs/current/Logging/Structs/Logger.html
