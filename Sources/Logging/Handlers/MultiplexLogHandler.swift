//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// A pseudo log handler that sends messages to multiple other log handlers.
///
/// ### Effective Logger.Level
///
/// When first initialized, the multiplex log handlers' log level is automatically set to the minimum of all the
/// provided log handlers.
/// This ensures that each of the handlers are able to log at their appropriate level
/// any log events they might be interested in.
///
/// Example:
/// If log handler `A` is logging at `.debug` level, and log handler `B` is logging at `.info` level, the log level of the constructed
/// `MultiplexLogHandler([A, B])` is set to `.debug`. This means that this handler will operate on debug messages,
/// while only logged by the underlying `A` log handler (since `B`'s log level is `.info`
/// and thus it would not actually log that log message).
///
/// If the log level is _set_ on a `Logger` backed by an `MultiplexLogHandler` the log level applies to *all*
/// underlying log handlers, allowing a logger to still select at what level it wants to log regardless of if the underlying
/// handler is a multiplex or a normal one. If for some reason one might want to not allow changing a log level of a specific
/// handler passed into the multiplex log handler, this is possible by wrapping it in a handler which ignores any log level changes.
///
/// ### Effective Logger.Metadata
///
/// Since a `MultiplexLogHandler` is a combination of multiple log handlers, the handling of metadata can be non-obvious.
/// For example, the underlying log handlers may have metadata of their own set before they are used to initialize the multiplex log handler.
///
/// The multiplex log handler acts purely as proxy and does not make any changes to underlying handler metadata other than
/// proxying writes that users made on a `Logger` instance backed by this handler.
///
/// Setting metadata is always proxied through to _all_ underlying handlers, meaning that if a modification like
/// `logger[metadataKey: "x"] = "y"` is made, all the underlying log handlers used to create the multiplex handler
/// observe this change.
///
/// Reading metadata from the multiplex log handler MAY need to pick one of conflicting values if the underlying log handlers
/// were previously initiated with metadata before passing them into the multiplex handler. The multiplex handler uses
/// the order in which the handlers were passed in during its initialization as a priority indicator - the first handler's
/// values are more important than the next handlers values, etc.
///
/// Example:
/// If the multiplex log handler was initiated with two handlers like this: `MultiplexLogHandler([handler1, handler2])`.
/// The handlers each have some already set metadata: `handler1` has metadata values for keys `one` and `all`, and `handler2`
/// has values for keys `two` and `all`.
///
/// A query through the multiplex log handler the key `one` naturally returns `handler1`'s value, and a query for `two`
/// naturally returns `handler2`'s value.
/// Querying for the key `all` will return `handler1`'s value, as that handler has a high priority,
/// as indicated by its earlier position in the initialization, than the second handler.
/// The same rule applies when querying for the `metadata` property of the multiplex log handler; it constructs `Metadata` uniquing values.
public struct MultiplexLogHandler: LogHandler {
    private var handlers: [any LogHandler]
    private var effectiveLogLevel: Logger.Level
    /// This metadata provider runs after all metadata providers of the multiplexed handlers.
    private var _metadataProvider: Logger.MetadataProvider?

    /// Create a multiplex log handler.
    ///
    /// - parameters:
    ///    - handlers: An array of `LogHandler`s, each of which will receive the log messages sent to this `Logger`.
    ///                The array must not be empty.
    public init(_ handlers: [any LogHandler]) {
        assert(!handlers.isEmpty, "MultiplexLogHandler.handlers MUST NOT be empty")
        self.handlers = handlers
        self.effectiveLogLevel = handlers.map { $0.logLevel }.min() ?? .trace
    }

    /// Create a multiplex log handler with the metadata provider you provide.
    /// - Parameters:
    ///   - handlers: An array of `LogHandler`s, each of which will receive every log message sent to this `Logger`.
    ///    The array must not be empty.
    ///   - metadataProvider: The metadata provider that adds metadata to log messages for this handler.
    public init(_ handlers: [any LogHandler], metadataProvider: Logger.MetadataProvider?) {
        assert(!handlers.isEmpty, "MultiplexLogHandler.handlers MUST NOT be empty")
        self.handlers = handlers
        self.effectiveLogLevel = handlers.map { $0.logLevel }.min() ?? .trace
        self._metadataProvider = metadataProvider
    }

    /// Get or set the log level configured for this `Logger`.
    ///
    /// > Note: Changing the log level threshold for a logger only affects the instance of the `Logger` where you change it.
    /// > It is acceptable for logging backends to have some form of global log level override
    /// > that affects multiple or even all loggers. This means a change in `logLevel` to one `Logger` might in
    /// > certain cases have no effect.
    public var logLevel: Logger.Level {
        get {
            self.effectiveLogLevel
        }
        set {
            self.mutatingForEachHandler { $0.logLevel = newValue }
            self.effectiveLogLevel = newValue
        }
    }

    /// The metadata provider.
    public var metadataProvider: Logger.MetadataProvider? {
        get {
            if self.handlers.count == 1 {
                if let innerHandler = self.handlers.first?.metadataProvider {
                    if let multiplexHandlerProvider = self._metadataProvider {
                        return .multiplex([innerHandler, multiplexHandlerProvider])
                    } else {
                        return innerHandler
                    }
                } else if let multiplexHandlerProvider = self._metadataProvider {
                    return multiplexHandlerProvider
                } else {
                    return nil
                }
            } else {
                var providers: [Logger.MetadataProvider] = []
                let additionalMetadataProviderCount = (self._metadataProvider != nil ? 1 : 0)
                providers.reserveCapacity(self.handlers.count + additionalMetadataProviderCount)
                for handler in self.handlers {
                    if let provider = handler.metadataProvider {
                        providers.append(provider)
                    }
                }
                if let multiplexHandlerProvider = self._metadataProvider {
                    providers.append(multiplexHandlerProvider)
                }
                guard !providers.isEmpty else {
                    return nil
                }
                return .multiplex(providers)
            }
        }
        set {
            self.mutatingForEachHandler { $0.metadataProvider = newValue }
        }
    }

    /// Log a message using the log level and source that you provide.
    ///
    /// - parameters:
    ///    - event: The log event containing the level, message, metadata, and source location.
    public func log(event: LogEvent) {
        for handler in self.handlers where handler.logLevel <= event.level {
            handler.log(event: event)
        }
    }

    @available(*, deprecated, renamed: "log(event:)")
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        self.log(
            event: LogEvent(
                level: level,
                message: message,
                metadata: metadata,
                source: source,
                file: file,
                function: function,
                line: line
            )
        )
    }

    /// Get or set the entire metadata storage as a dictionary.
    public var metadata: Logger.Metadata {
        get {
            var effective: Logger.Metadata = [:]
            // as a rough estimate we assume that the underlying handlers have a similar metadata count,
            // and we use the first one's current count to estimate how big of a dictionary we need to allocate:

            // !-safe, we always have at least one handler
            effective.reserveCapacity(self.handlers.first!.metadata.count)

            for handler in self.handlers {
                effective.merge(handler.metadata, uniquingKeysWith: { _, handlerMetadata in handlerMetadata })
                if let provider = handler.metadataProvider {
                    effective.merge(provider.get(), uniquingKeysWith: { _, provided in provided })
                }
            }
            if let provider = self._metadataProvider {
                effective.merge(provider.get(), uniquingKeysWith: { _, provided in provided })
            }

            return effective
        }
        set {
            self.mutatingForEachHandler { $0.metadata = newValue }
        }
    }

    /// Add, change, or remove a logging metadata item.
    ///
    /// > Note: Changing the logging metadata only affects the instance of the `Logger` where you change it.
    public subscript(metadataKey metadataKey: Logger.Metadata.Key) -> Logger.Metadata.Value? {
        get {
            for handler in self.handlers {
                if let value = handler[metadataKey: metadataKey] {
                    return value
                }
            }
            return nil
        }
        set {
            self.mutatingForEachHandler { $0[metadataKey: metadataKey] = newValue }
        }
    }

    private mutating func mutatingForEachHandler(_ mutator: (inout any LogHandler) -> Void) {
        for index in self.handlers.indices {
            mutator(&self.handlers[index])
        }
    }
}
