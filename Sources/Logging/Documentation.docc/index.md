# ``Logging``

A Logging API for Swift.

## Getting Started

If you have a server-side Swift application, or maybe a cross-platform (for example Linux & macOS) app/library, and you would like to log, we think targeting this logging API package is a great idea. Below you'll find all you need to know to get started.

### Log handler implementations

This package offers the common Logging API as well as a very simple stdout log handler.

In a real system or application, you will want to use one of the many community maintained log handler implementations.

Please refer to the [complete list of community maintained logging backend implementations](https://github.com/apple/swift-log#selecting-a-logging-backend-implementation-applications-only).

## Topics

### Logging API

- ``Logger``
- ``LoggingSystem``

### Log Handlers

- ``LogHandler``
- ``MultiplexLogHandler``
- ``StreamLogHandler``
- ``SwiftLogNoOpLogHandler``

