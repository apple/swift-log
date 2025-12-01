# 001: Choosing log levels

Select appropriate log levels in applications and libraries.

## Overview

SwiftLog defines seven log levels, and choosing the right level is crucial for
creating well-behaved libraries that don't overwhelm logging systems or misuse
severity levels. This practice provides clear guidance on when to use each
level.

### Motivation

Libraries must be well-behaved across various use cases and cannot assume
specific logging backend configurations. Using inappropriate log levels can
flood production logs, trigger false alerts, or make debugging more difficult.
Following consistent log level guidelines ensures your library integrates well
with diverse application environments.

### Log levels

SwiftLog defines seven log levels via ``Logger/Level``, ordered from least to
most severe:

- ``Logger/Level/trace``
- ``Logger/Level/debug``
- ``Logger/Level/info``
- ``Logger/Level/notice``
- ``Logger/Level/warning``
- ``Logger/Level/error``
- ``Logger/Level/critical``

### Level guidelines

How you use log levels depends in large part if you are developing a library, or
an application which bootstraps its logging system and is in full control over
its logging environment.

#### For libraries

Libraries should use **info level or less severe** (info, debug, trace).

Libraries **should not** log information on **warning or more severe levels**,
unless it is a one-time (for example during startup) warning, that cannot lead
to overwhelming log outputs.

Each level serves different purposes:

##### Trace Level
- **Usage**: Log everything needed to diagnose hard-to-reproduce bugs.
- **Performance**: May impact performance; assume it won't be used in production.
- **Content**: Internal state, detailed operation flows, diagnostic information.

##### Debug Level
- **Usage**: May be enabled in some production deployments.
- **Performance**: Should not significantly undermine production performance.
- **Content**: High-level operation overview, connection events, major decisions.

##### Info Level
- **Usage**: Reserved for things that went wrong but can't be communicated
through other means, like throwing from a method.
- **Examples**: Connection retry attempts, fallback mechanisms, recoverable
  failures.
- **Guideline**: Use sparingly - Don't use for normal successful operations.

#### For applications

Applications can use **any level** depending on the context and what they want
to achieve. Applications have full control over their logging strategy.

#### Configuring logger log levels

It depends on the use-case of your application which log level your logger
should use. For **console and other end-user-visible displays**: Consider using
**notice level** as the minimum visible level to avoid overwhelming users with
technical details.

### Example

#### Recommended: Libraries should use info level or lower

```swift
// ✅ Good: Trace level for detailed diagnostics
logger.trace("Connection pool state", metadata: [
    "active": "\(activeConnections)",
    "idle": "\(idleConnections)",
    "pending": "\(pendingRequests)"
])

// ✅ Good: Debug level for high-value operational info
logger.debug("Database connection established", metadata: [
    "host": "\(host)",
    "database": "\(database)",
    "connectionTime": "\(duration)"
])

// ✅ Good: Info level for issues that can't be communicated through other means
logger.info("Connection failed, retrying", metadata: [
    "attempt": "\(attemptNumber)",
    "maxRetries": "\(maxRetries)",
    "host": "\(host)"
])
```

#### Use sparingly: Warning and error levels

```swift
// ✅ Good: One-time startup warning or error
logger.warning("Deprecated TLS version detected. Consider upgrading to TLS 1.3")
```

#### Avoid: Logging potentially intentional failures at info level

Some failures may be completely intentional from the high-level perspective of a
developer or system using your library. For example: failure to resolve a
domain, failure to make a request, or failure to complete some task;

Instead, log at debug or trace levels and offer alternative ways to observe
these behaviors, for example using `swift-metrics` to emit counts.

```swift
// ❌ Bad: Normal operations at info level flood production logs
logger.info("Request failed")
```

#### Avoid: Normal operations at info level

```swift
// ❌ Bad: Normal operations at info level flood production logs
logger.info("HTTP request received")
logger.info("Database query executed")
logger.info("Response sent")

// ✅ Good: Use appropriate levels instead
logger.debug("Processing request", metadata: ["path": "\(path)"])
logger.trace("Query", metadata: ["sql": "\(query)"])
logger.debug("Request completed", metadata: ["status": "\(status)"])
```

### Disable log levels during compilation

SwiftLog provides compile-time traits to eliminate less severe log levels from
your binary reducing the runtime overhead.

#### Motivation

When deploying applications to production, you often know in advance which log
levels will never be needed. For example, a production service might only need
warning and above, while trace and debug levels are only useful during
development. By using traits, you can completely remove these unnecessary log
levels at compile time, achieving zero runtime overhead.

#### Available traits

SwiftLog defines seven maximum log level traits, ordered from most permissive
to most restrictive:

- `MaxLogLevelDebug`: Debug and above available (compiles out trace)
- `MaxLogLevelInfo`: Info and above available (compiles out trace, debug)
- `MaxLogLevelNotice`: Notice and above available (compiles out trace, debug,
  info)
- `MaxLogLevelWarning`: Warning and above available (compiles out trace, debug,
  info, notice)
- `MaxLogLevelError`: Error and above available (compiles out trace, debug,
  info, notice, warning)
- `MaxLogLevelCritical`: Only critical available (compiles out all except
  critical)
- `MaxLogLevelNone`: All logging compiled out (no log levels available)

By default (when no traits are specified), all log levels are available.

When you specify a maximum log level trait, all less severe levels are
completely removed from your binary at compile time. This applies to both
level-specific methods (e.g., `logger.debug()`) and calls to the generic
`logger.log(level:)` method.

> Note: Traits are additive. If multiple max level traits are specified, the
> most restrictive one takes effect.

#### Example

To enable a trait, specify it when declaring your package dependency:

```swift
// In your Package.swift:
dependencies: [
    .package(
        url: "https://github.com/apple/swift-log.git",
        from: "1.0.0",
        traits: ["MaxLogLevelWarning"]
    )
]
```

With `MaxLogLevelWarning` enabled, all trace, debug, info, and notice log
statements are compiled out:

```swift
// These become no-ops (compiled out completely):
logger.trace("This will not be in the binary")
logger.debug("This will not be in the binary")
logger.info("This will not be in the binary")
logger.notice("This will not be in the binary")
logger.log(level: .debug, "This will not log anything")

// These work normally:
logger.warning("This still works")
logger.error("This still works")
logger.critical("This still works")
logger.log(level: .error, "This still works")
```
