# SSWG Logging API

* Proposal: SSWG-xxxx
* Authors: [Johannes Weiss](https://github.com/weissi) & [Tomer Doron](https://github.com/tomerd)
* Status: **Implemented**
* Pitch: [Server: Pitches/Logging](https://forums.swift.org/t/logging/16027)

## Introduction

Almost all production server software needs logging that works with a variety of packages. So, there have been a number of different ecosystems (e.g. Vapor, Kitura, Perfect, ...) that came up with their own solutions for logging, tracing, metrics, etc.
The SSWG however aims to provide a number of packages that can be shared across within the whole Swift on Server ecosystem so we need some amount of standardisation . Because it's unlikely that all parties can agree on one full logging implementation this is proposing to establish a SSWG logging API that can be implemented by various logging backends (called `LogHandler`) which then write the log messages to disk, database, etc.

## Motivation

As outlined above we should standardise on an API that if well adopted and applications should allow users to mix and match libraries from different vendors with a consistent logging solution.
The aim is to support all widely used logging models such as:

- one global logger, similar to what IBM's [LoggerAPI](https://github.com/IBM-Swift/LoggerAPI) offers
- a scoped logger for example one per class/sub-system
- a local logger that is always explicitly passed around where the logger itself can be a value type

There are also a number of features that most agreed we will need to support, most importantly:

- log levels
- attaching meta-data (such as a request ID to the logger which will then log it with all log messages)
- being able to make up a logger out of thin air; because we don't have one true way of dependency injection and it's better to log in a slightly different configuration than just reverting to `print(...)`

Another idea was that we try that at least not logging a message can be relatively fast.

## Proposed solution

The proposed solution is to have one `struct Logger` which has a supports a number of different methods to possibly emit a log message. Namely `trace`, `debug`, `info`, `warning` and `error`. To send a log message it's usually enough to

    logger.info("hello there")
    
This now raises the question: Where does `logger` come from? To this question there is two answers: Either the environment (could be a global variable, could be a function parameter, could be a class property, ...) provides `logger` or if not, it is always possible to obtain a logger from the logging system itself (a.k.a. making up a logger out of thin air):

    let logger = Logging.make("com.example.example-app")
    logger.info("hi again")

To get the best logging experience and performance, it is advisable not to `.make` new `Logger`s all time but rather pass them around, store them in a global/instance variable, etc.

Apart from knowing where I can obtain a logger it would be good to know what we can do with such a logger:

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

### Custom log handlers

But for now let's put the logging meta-data aside and focus on the how we can create and configure a custom logging backend. As seen before, `Logging.make` is what gives us a fresh logger but that raises the question what kind of logging backend will I actually get when calling `Logging.make`? The answer: It's configurable _per application_. The application, likely in the `main` function sets up the logging backend it wishes the whole application to use, libraries should never change the logging implementation as that is something owned by the application. Configuring the logging backend is also straightforward:

    Logging.bootstrap(MyFavouriteLoggingImplementation.init)
    
This instructs the `Logging` system to install `MyFavouriteLoggingImplementation` as the logging backend (`LogHandler`) to use. This should only be done once at the beginning of the program. Is it hard to implement `MyFavouriteLoggingImplementation`? No, you just need to conform to `protocol LogHandler`:

```swift
public protocol LogHandler {
    func log(level: LogLevel, message: String, file: String, function: String, line: UInt)
    
    var logLevel: LogLevel { get set }
    
    subscript(metadataKey metadataKey: String) -> String? { get set }
    
    var metadata: [String: String]? { get set } 
}
```

`log` and `logLevel` need to always be implemented. Logging meta-data can in theory be implemented by always returning `nil` and ignoring all metadata that is being attached to a logger but it's highly recommended to store them in an appropriate way with the `LogHandler`, for example in a dictionary.

The implementation of the `log` function itself is also pretty straightforward: If `log` is invoked, `Logger` itself already decided that given the current `logLevel`, `message` should be logged. In other words, `LogHandler` does not even need to compare `level` to the currently configured level. That makes the shortest possible `LogHandler` implementation really quite short:

```swift
public struct ShortestPossibleLogHandler: LogHandler {
    public var logLevel: LogLevel = .info 
    
    public init(_ id: String) {}

    public func log(level: LogLevel, message: String, file: String, function: String, line: UInt) {
        print(message)
    }
    
    public subscript(metadataKey metadataKey: String) -> String? {
        get { return nil }
        set { }
    }
    
    public var metadata: [String: String] {
        get { return nil }
        set { }
    }
}
```

which can be installed using

    Logging.bootstrap(ShortestPossibleLogHandler.init)

### Supported models

This is SSWG proposal about a logger API that intends to support a number programming models:

- explicit logger passing (see `ExplicitLoggerPassingExample.swift`)
- one global logger (see `OneGlobalLoggerExample.swift`)
- one logger per sub-system (see `LoggerPerSubsystem.swift`)

The file `RandomExample.swift` contains demoes of some other things that you may want to do.

## State

This is an early proposal so there are still plenty of things to decide and tweak and I'd invite everybody to participate.

### Feedback Wishes

Feedback that would really be great is:

- if anything, what does this proposal *not cover* that you will definitely need
- if anything, what could we remove from this and still be happy?
- API-wise: what do you like, what don't you like?

Feel free to post this as message on the SSWG forum and/or github issues in this repo.

### Open Questions

Very many. But here a couple that come to my mind:

- currently attaching metadata to a logger is done through `subscript(metadataKey metadataKey: String) -> String? { get set }`
  clearly setting and deleting extra metadata is necessary. But reading it is really not. Should we make it `addContext(key: String, value: String)` and `removeContext(key:String)` instead?  
- should the logging metadata values be `String`?
- should this library include an [MDC](https://logback.qos.ch/manual/mdc.html) API? should it be a seperate module? or a seperate library? [SLF4J](https://www.slf4j.org/manual.html#mdc) which is the moral equivilant of this API in the JVM ecosystem does include one
