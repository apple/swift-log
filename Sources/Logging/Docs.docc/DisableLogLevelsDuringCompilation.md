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
