# SSWG Logging API

* Proposal: SSWG-xxxx
* Authors: [Johannes Weiss](https://github.com/weissi) & [Tomer Doron](https://github.com/tomerd)
* Status: [Implemented](https://github.com/weissi/swift-server-logging-api-proposal)
* Pitch: [Server: Pitches/Logging](https://forums.swift.org/t/logging/16027)

## Introduction

Almost all production server software needs logging that works with a variety of packages. So, there have been a number of different ecosystems (e.g. Vapor, Kitura, Perfect, ...) that came up with their own solutions for logging, tracing, metrics, etc.
The SSWG however aims to provide a number of packages that can be shared across within the whole Swift on Server ecosystem so we need some amount of standardisation. Because different applications have different requirements on what logging should exactly do, we're proposing to establish a SSWG logging API that can be implemented by various logging backends (called `LogHandler`).
`LogHandler`s are responsible to format the log messages and to deliver them on. The delivery might simply go to `stdout`, might be saved to disk or a database, or might be sent off to another machine to aggregate logs for multiple services. The implementation of `LogHandler`s is out of scope of this proposal and also doesn't need to be standardised across all applications. What matters is a standard API libraries can use without needing to know where the log will end up eventually.


## Motivation

As outlined above we should standardise on an API that if well adopted and applications should allow users to mix and match libraries from different vendors while still maintaining a consistent logging.
The aim is to support all widely used logging models such as:

- one global logger, ie. one application-wise global that's always accessible
- a scoped logger for example one per class/sub-system
- a local logger that is always explicitly passed around where the logger itself can be a value type

There are also a number of features that most agreed we will need to support, most importantly:

- log levels
- attaching meta-data (such as a request ID) to the logger
- being able to 'make up a logger out of thin air'; because we don't have one true way of dependency injection and it's better to log in a slightly different configuration than just reverting to `print(...)`

On top of the hard requirements the aim is to make the logging calls as fast as possible if nothing will be logged. If a log message is emitted, it will be mostly up to the `LogHandler`s to do so in a fast enough way. How fast 'fast enough' is depends on the requirements, some will optimise for never losing a log message and others might optimise for the lowest possible latency even if that might not guarantee log message delivery.

## Proposed solution

The proposed solution is to have one `struct Logger` which has a supports a number of different methods to possibly emit a log message. Namely `trace`, `debug`, `info`, `warning` and `error`. To send a log message it's usually enough to

    logger.info("hello there")
    
This now raises the question: Where does `logger` come from? To this question there is two answers: Either the environment (could be a global variable, could be a function parameter, could be a class property, ...) provides `logger` or if not, it is always possible to obtain a logger from the logging system itself (a.k.a. making up a logger out of thin air):

    let logger = Logging.make("com.example.example-app")
    logger.info("hi again")

To get the best logging experience and performance, it is advisable to use `.make` to pass `Logger`s around or store them in a global/instance variable rather than `.make`ing new `Logger`s whenever one needs to log a message.

Apart from knowing where one obtains a `Logger` from, it should be interesting to see what one can do with one:

```swift
public struct Logger {
    public var logLevel: LogLevel

    public func trace(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line)
    
    public func debug(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line)
    
    public func info(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line)
    
    public func warn(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line)
    
    public func error(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line)
    
    public subscript(metadataKey metadataKey: String) -> String? { get set }
    
    public var metadata: LoggingMetadata? { get set }
}
```

I guess `logLevel`, `trace`, `debug`, `info`, `warning` and `error` are rather self-explanatory but the meta-data related members need some more explanation.

## Detailed design

### Logging meta-data

In production environments that are under heavy load it's often a great help (and many would say required) that certain meta-data can be attached to every log message. Instead of seeing

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

now it's fairly straightforward to identify that the database issue was in the request where we were dealing with user 'Talor' because the request ID matches. The question is: How can we decorate all our log messages with the 'request UUID' or other information that we may need to correlate the messages? The easy option is:

    log.info("user \(userID) logged in [request_UUID: \(currentRequestUUID)]")

and similarly for all log messages. But it quickly becomes tedious appending `[request_UUID: \(currentRequestUUID)]` to every single log message. The other option is this:

    logger[metadataKey: "request_UUID"] = currentRequestUUID
    
and from then on a simple

    logger.info("user \(userID) logged in")

is enough because the logger has been decorated with the request UUID already and from now on carries this information around.

### Custom `LogHandler`s

Now, let's put the logging meta-data aside and focus on the how we can create and configure a custom logging backend. As seen before, `Logging.make` is what gives us a fresh logger but that raises the question what kind of logging backend will I actually get when calling `Logging.make`? The answer: It's configurable _per application_. The application -- likely in its main function -- sets up the logging backend it wishes the whole application to use. Libraries should never change the logging implementation as that should owned by the application. Setting up the `LogHandler` to be used is straightforward:

    Logging.bootstrap(MyFavouriteLoggingImplementation.init)
    
This instructs the `Logging` system to install `MyFavouriteLoggingImplementation` as the `LogHandler` to use. This should only be done once at the start of day and is usually left alone thereafter.

Next we should discuss how one would implement `MyFavouriteLoggingImplementation`. It's enough to conform to the following protocol:

```swift
public protocol LogHandler {
    func log(level: LogLevel, message: String, file: String, function: String, line: UInt)
    
    var logLevel: LogLevel { get set }
    
    subscript(metadataKey metadataKey: String) -> String? { get set }
    
    var metadata: [String: String]? { get set } 
}
```

`log` and `logLevel` need to always be implemented. Logging meta-data can be implemented by always returning `nil` and ignoring all metadata that is being attached to a logger but it is highly recommended to store the metadata in an appropriate way with the `LogHandler` and emit it with all log messages.

The implementation of the `log` function itself is rather straightforward: If `log` is invoked, `Logger` itself already decided that given the current `logLevel`, `message` should be logged. In other words, `LogHandler` does not even need to compare `level` to the currently configured level. That makes the shortest possible `LogHandler` implementation really quite short:

```swift
public struct ShortestPossibleLogHandler: LogHandler {
    public var logLevel: LogLevel = .info 
    
    public init(_ id: String) {}

    public func log(level: LogLevel, message: String, file: String, function: String, line: UInt) {
        print(message)
    }
    
    public subscript(metadataKey metadataKey: String) -> String? {
        // ignore all metadata, not recommended
        get { return nil }
        set { }
    }
    
    public var metadata: [String: String] {
        // ignore all metadata, not recommended
        get { return nil }
        set { }
    }
}
```

which can be installed using

    Logging.bootstrap(ShortestPossibleLogHandler.init)

### Supported logging models

This API intends to support a number programming models:

1. explicit logger passing (see [`ExplicitLoggerPassingExample.swift`](https://github.com/weissi/swift-server-logging-api-proposal/blob/master/Sources/Examples/ExplicitLoggerPassingExample.swift))
2. one global logger (see [`OneGlobalLoggerExample.swift`](https://github.com/weissi/swift-server-logging-api-proposal/blob/master/Sources/Examples/OneGlobalLoggerExample.swift))
3. one logger per sub-system (see [`LoggerPerSubsystemExample.swift`](https://github.com/weissi/swift-server-logging-api-proposal/blob/master/Sources/Examples/LoggerPerSubsystemExample.swift))

Because there are fundamental differences with those models it is not mandated whether the `LogHandler` holds the logging configuration (log level and meta-data) as a value or as a reference. Both systems make sense and it depends on the architecture of the application and the requirements to decide what is more appropriate.

Certain systems will also want to store the logging meta-data in a thread/queue-local variable, some may even want try to automatically forward the meta-data across thread switches together with the control flow. In the Java-world this model is called MDC, your mileage in Swift may vary and again hugely depends on the architecture of the system.

I believe designing a [MDC (mapped diagnostic context)](https://logback.qos.ch/manual/mdc.html) solution is out of scope for this proposal but the proposed API can work with such a system (see [examples](https://github.com/weissi/swift-server-logging-api-proposal/blob/50a8c8fdaceef62f1035d02ce0c8c5aa62252ff0/Tests/LoggingTests/MDCTest.swift)).


## Seeking feedback

Feedback that would really be great is:

- if anything, what does this proposal *not cover* that you will definitely need
- if anything, what could we remove from this and still be happy?
- API-wise: what do you like, what don't you like?


### Open Questions

A couple of questions come to mind:

- Currently, attaching metadata to a logger is done through `subscript(metadataKey metadataKey: String) -> String? { get set }`. In code it would be `logger[metadataKey: "request_uuid"] = "..."`, is this a good use of a subscript?
- Should the logging metadata values be `String`?
- Should this library include an [MDC](https://logback.qos.ch/manual/mdc.html) API? Should it be a separate module? or a separate library? [SLF4J](https://www.slf4j.org/manual.html#mdc) which is the moral equivalent of this API in the Java ecosystem does include one.
