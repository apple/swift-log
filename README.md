
# Proposal Review: SSWG-0001 (Server Logging API)

After the great [discussion thread](https://forums.swift.org/t/server-logging-api/18834), we are proposing this as a final revision of this proposal and enter the proposal review phase which will run until the 20th January 2019.

We have integrated most of the feedback from the discussion thread so even if you have read the previous version, you will find some changes that you hopefully agree with. To highlight a few of the major changes:

- Logging metadata is now structures and now supports nested dictionaries and list values, in addition to strings of course.
- only locally relevant metadata can now be passed to the individual log methods.
- ship a multiplex logging solution with the API package

The feedback model will be very similar to the one known from Swift Evolution. The community is asked to provide feedback in the way outlined below and after the review period finishes, the SSWG will -- based on the community feedback -- decide whether to promote the proposal to the [Sandbox](https://github.com/swift-server/sswg/blob/master/process/incubation.md#process-diagram) maturity level or not.

### What goes into a review of a proposal?

The goal of the review process is to improve the proposal under review through constructive criticism and, eventually, determine the evolution of the server-side Swift ecosystem.

When reviewing a proposal, here are some questions to consider:

- What is your evaluation of the proposal?

- Is the problem being addressed significant enough?

- Does this proposal fit well with the feel and direction of Swift on Server?

- If you have used other languages or libraries with a similar feature, how do you feel that this proposal compares to those?

- How much effort did you put into your review? A glance, a quick reading, or an in-depth study?

Thank you for contributing to the Swift Server Work Group!

### What happens if the proposal gets accepted?

If this proposal gets accepted, the official repository will be created and the code (minus examples, the proposal text, etc) will be submitted. The repository will then become usable as a SwiftPM package and a version (likely `0.1.0`) will be tagged. The development (in form of pull requests) will continue as a regular open-source project.

---

# Server Logging API

* Proposal: SSWG-0001
* Authors: [Johannes Weiss](https://github.com/weissi) & [Tomer Doron](https://github.com/tomerd)
* Preferred initial maturity level: [Sandbox](https://github.com/swift-server/sswg/blob/master/process/incubation.md#process-diagram)
* Name: `swift-server-logging-api`
* Sponsor: Apple
* Status: Active review (9th...20th January, 2019)
* Implementation: [https://github.com/weissi/swift-server-logging-api-proposal](https://github.com/weissi/swift-server-logging-api-proposal), if accepted, a fresh repository will be created under github.com/apple
* External dependencies: *none*
* License: if accepted, it will be released under the [Apache 2](https://www.apache.org/licenses/LICENSE-2.0.html) license
* Pitch: [Server: Pitches/Logging](https://forums.swift.org/t/logging/16027)
* Description: A flexible API package that aims to become the standard logging API which Swift packages can use to log. The formatting and delivery/persistence of the log messages is handled by other packages and configurable by the individual applications without requiring users of the API package to change.

## Introduction

Almost all production server software needs logging that works with a variety of packages. So far, there have been a number of different ecosystems (e.g. Vapor, Kitura, Perfect, ...) that came up with their own solutions for logging, tracing, metrics, etc.

The SSWG however aims to provide a number of packages that can be shared across within the whole Swift on Server ecosystem so we need some amount of standardisation. Because different applications have different requirements on what logging should exactly do, we are proposing to establish a server-side Swift logging API that can be implemented by various logging backends (called `LogHandler`).
`LogHandler`s are responsible to format the log messages and to deliver/persist them. The delivery might simply go to `stdout`, might be saved to disk or a database, or might be sent off to another machine to aggregate logs for multiple services. The implementation of concrete `LogHandler`s is out of scope of this proposal and also doesn't need to be standardised across all applications. What matters is a standard API libraries can use without needing to know where the log will end up eventually.


## Motivation

As outlined above we should standardise on an API that if well adopted and applications should allow users to mix and match libraries from different vendors while still maintaining a consistent logging.
The aim is to support all widely used logging models such as:

- one global logger, ie. one application-wise global that's always accessible
- a scoped logger for example one per class/sub-system
- a local logger that is always explicitly passed around where the logger itself can be a value type

There are also a number of features that most agreed we will need to support, most importantly:

- log levels
- attaching structured metadata (such as a request ID) to the logger and individual log messages
- being able to 'make up a logger out of thin air'; because we don't have one true way of dependency injection and it's better to log in a slightly different configuration than just reverting to `print(...)`

On top of the hard requirements the aim is to make the logging calls as fast as possible if nothing will be logged. If a log message is emitted, it will be mostly up to the `LogHandler`s to do so in a fast enough way. How fast 'fast enough' is depends on the requirements, some will optimise for never losing a log message and others might optimise for the lowest possible latency even if that might not guarantee log message delivery.

## Proposed solution

Overall, we propose three different core, top-level types:

1. `LogHandler`, a `protocol` which defines the interface a logging backend needs to implement in order to be compatible.
2. `Logging`, the logging system itself, used to configure the `LogHandler` to be used as well as to retrieve a `Logger`.
3. `Logger`, the core type which is used to log messages.

To get started with this API, a user only needs to become familiar with the `Logger` type which has a few straightforward methods that can be used to log messages as a certain log level, for example `logger.info("Hello world!")`. There's one step a user needs to perform before being able to log: The have to have a `Logger` instance. This instance can be either retrieved from the logging system itself using

    let logger = Logging.make("my-app")

or through some different way provided by the framework they use or a more specialised logger package which might offer a global instance.

### The `Logger`

We propose one `struct Logger` which has a supports a number of different methods to possibly emit a log message. Namely `trace`, `debug`, `info`, `warning`, and `error`. To send a log a message you pick a log level and invoke the `Logger` method with the same name, for example

    logger.error("Houston, we've had a problem")
    
We already briefly touched on this: Where do we get `logger: Logger` from? This question has two answers: Either the environment (could be a global variable, could be a function parameter, could be a class property, ...) provides `logger` or if not, it is always possible to obtain a logger from the logging system itself:

    let logger = Logging.make("com.example.app")
    logger.warning("uh oh, this is unexpected")

To get the best logging experience and performance, it is advisable to use `.make` to pass `Logger`s around or store them in a global/instance variable rather than `.make`ing new `Logger`s whenever one needs to log a message.

## Detailed design

The full API of `Logger` is visible below except for one detail that is removed for readability: All the logging methods have parameters with default values indicating the file, function, and line of the log message.

```swift
public struct Logger {
    public var logLevel: Logging.Level

    public func log(level: Logging.Level, message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil)

    public func trace(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil)
    
    public func debug(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil)

    public func info(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil)
    
    public func warning(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil)
    
    public func error(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil)
    
    public subscript(metadataKey metadataKey: String) -> Logging.Metadata.Value? { get set }
    
    public var metadata: Logging.Metadata? { get set }
}
```

The `logLevel` property as well as the `trace`, `debug`, `info`, `warning`, and `error` methods are probably self-explanatory. But the information that can be passed alongside a log message deserves some special mentions:

- `message`, a `String` that is the log message itself and the only required argument.
- `metadata`, a dictionary of metadata information attached to only this log message. Please see below for a more detailed discussion of logging metadata.
- `error`, an optional `Error` that can be sent along with `warning` and `error` messages indicating a possible error that led to this failure.

Both, `message` and `metadata` are `@autoclosure` parameters which means that if the message does not end up being logged (because it's below the currently configured log level) no unnecessary processing is done rendering the `String` or creating the metadata information.

Instead of picking one of the `trace`, `debug`, `info`, etc methods it is also possible to use the `log` method passing the desired log level as a parameter.

### Logging metadata

In production environments that are under heavy load it's often a great help (and many would say required) that certain metadata can be attached to every log message. Instead of seeing

```
info: user 'Taylor' logged in
info: user 'Swift' logged in
warn: could not establish database connection: no route to host
```

where it might be unclear if the warning message belong to the session with user 'Taylor' or user 'Swift' or maybe to none of the above, the following would be much clearer:

```
info: user 'Taylor' logged in [request_UUID: 9D315532-FA5C-4E11-88E9-520C877F58B5]
info: user 'Swift' logged in [request_UUID: 35CC2687-CD1E-45A3-80B7-CCCE278797E6]
warn: could not establish database connection: no route to host [request_UUID: 9D315532-FA5C-4E11-88E9-520C877F58B5]
```

now it's fairly straightforward to identify that the database issue was in the request where we were dealing with user 'Taylor' because the request ID matches. The question is: How can we decorate all our log messages with the 'request UUID' or other information that we may need to correlate the messages? The easy option is:

    log.info("user \(userID) logged in [request_UUID: \(currentRequestUUID)]")

and similarly for all log messages. But it quickly becomes tedious appending `[request_UUID: \(currentRequestUUID)]` to every single log message. The other option is this:

    logger[metadataKey: "request_UUID"] = currentRequestUUID
    
and from then on a simple

    logger.info("user \(userID) logged in")

is enough because the logger has been decorated with the request UUID already and from now on carries this information around.

In other cases however, it might be useful to attach some metadata to only one message and that can be achieved by using the `metadata` parameter from above:

    logger.trace("user \(userID) logged in",
                 metadata: ["extra_user_info": [ "favourite_colour": userFaveColour,
                                                 "auth_method": "password" ]])

The above invocation will log the message alongside metadata merged from the `logger`'s metadata and the metadata provided with the `logger.trace` call.

The logging metadata is of type `typealias Logging.Metadata = [String: Metadata.Value]` where `Metadata.Value` is the following `enum` allowing nested structures rather than just `String`s as values.

    public enum MetadataValue {
        case string(String)
        indirect case dictionary(Metadata)
        indirect case array([Metadata.Value])
    }

Users usually don't need to interact with the `Metadata.Value` type directly as it conforms to the `ExpressibleByStringLiteral`, `ExpressibleByStringInterpolation`, `ExpressibleByDictionaryLiteral`, and `ExpressibleByArrayLiteral` protocols and can therefore be constructed using the string, array, and dictionary literals.

Examples:

    logger.info("you can attach strings, lists, and nested dictionaries",
                metadata: ["key_1": "and a string value",
                           "key_2": ["and", "a", "list", "value"],
                           "key_3": ["where": ["we": ["pretend", ["it": ["is", "all", "Objective C", "again"]]]]]])
    logger[metadataKey: "keys-are-strings"] = ["but", "values", ["are": "more"]]
    logger.warning("ok, we've seen enough now.")



### Custom `LogHandler`s

Just like metadata, custom `LogHandler`s are an advanced feature and users will typically just choose a pre-existing package that formats and persists/delivers the log messages in an appropriate way. Said that, the proposed package here is an API package and it will become much more useful if the community create a number of useful `LogHandler`s to say format the log messages with colour or ship them to Splunk/ELK.

We have already seen before that `Logging.make` is what gives us a fresh logger but that raises the question what kind of logging backend will I actually get when calling `Logging.make`? The answer: It's configurable _per application_. The application -- likely in its main function -- sets up the logging backend it wishes the whole application to use. Libraries should never change the logging implementation as that should owned by the application. Setting up the `LogHandler` to be used is straightforward:

    Logging.bootstrap(MyFavouriteLoggingImplementation.init)
    
This instructs the `Logging` system to install `MyFavouriteLoggingImplementation` as the `LogHandler` to use. This should only be done once at the start of day and is usually left alone thereafter.

Next, we should discuss how one would implement `MyFavouriteLoggingImplementation`. It's enough to conform to the following protocol:

```swift
public protocol LogHandler {
    func log(level: Logging.Level, message: String, metadata: Logging.Metadata?, error: Error?, file: StaticString, function: StaticString, line: UInt)

    subscript(metadataKey _: String) -> Logging.Metadata.Value? { get set }

    var metadata: Logging.Metadata { get set }

    var logLevel: Logging.Level { get set }
}
```

The implementation of the `log` function itself is rather straightforward: If `log` is invoked, `Logger` itself already decided that given the current `logLevel`, `message` should be logged. In other words, `LogHandler` does not even need to compare `level` to the currently configured level. That makes the shortest possible `LogHandler` implementation really quite short:

```swift
public struct ShortestPossibleLogHandler: LogHandler {
    public var logLevel: Logging.Level = .info
    public var metadata: Logging.Metadata = [:]
    
    public init(_ id: String) {}
    
    public func log(level: Logging.Level, message: String, metadata: Logging.Metadata?, error: Error?, file: StaticString, function: StaticString, line: UInt) {
        print(message) // ignores all metadata, not recommended
    }
    
    public subscript(metadataKey key: String) -> Metadata.Value? {
        get { return self.metadata[key] }
        set { self.metadata[key] = newValue }
    }
}
```

which can be installed using

    Logging.bootstrap(ShortestPossibleLogHandler.init)

### Supported logging models

This API intends to support a number programming models:

1. Explicit logger passing, ie. handing loggers around as value-typed variables explicitly to everywhere log messages get emitted from.
2. One global logger, ie. having one global that is _the_ logger.
3. One logger per sub-system, ie. having a separate logger per sub-system which might be a file, a class, a module, etc.

Because there are fundamental differences with those models it is not mandated whether the `LogHandler` holds the logging configuration (log level and metadata) as a value or as a reference. Both systems make sense and it depends on the architecture of the application and the requirements to decide what is more appropriate.

Certain systems will also want to store the logging metadata in a thread/queue-local variable, some may even want try to automatically forward the metadata across thread switches together with the control flow. In the Java-world this model is called MDC, your mileage in Swift may vary and again hugely depends on the architecture of the system.

I believe designing a [MDC (mapped diagnostic context)](https://logback.qos.ch/manual/mdc.html) solution is out of scope for this proposal but the proposed API can work with such a system (see [examples](https://github.com/weissi/swift-server-logging-api-proposal/blob/50a8c8fdaceef62f1035d02ce0c8c5aa62252ff0/Tests/LoggingTests/MDCTest.swift)).

### Multiple log destinations

Finally, the API package will offer a solution to log to multiple `LogHandler`s at the same time through the `MultiplexLogging` facility. Let's assume you have two `LogHandler` implementations `MyConsoleLogger` & `MyFileLogger` and you wish to delegate the log messages to both of them, then the following one-time initialisation of the logging system will take care of this:

    let multiLogging = MultiplexLogging([MyConsoleLogger().make, MyFileLogger().make])
    Logging.bootstrap(multiLogging.make)
