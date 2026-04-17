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

/// A no-operation log handler, used when no logging is required
public struct SwiftLogNoOpLogHandler: LogHandler {
    /// Creates a no-op log handler.
    public init() {}

    /// Creates a no-op log handler.
    public init(_: String) {}

    /// A proxy that discards every log event it receives.
    ///
    /// - parameters:
    ///    - event: The log event to discard.
    @inlinable public func log(event: LogEvent) {}

    @available(*, deprecated, renamed: "log(event:)")
    @inlinable public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {}

    @available(*, deprecated, renamed: "log(event:)")
    @inlinable public func log(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        metadata: Logging.Logger.Metadata?,
        file: String,
        function: String,
        line: UInt
    ) {}

    /// Add, change, or remove a logging metadata item.
    ///
    /// > Note: Changing the logging metadata only affects the instance of the `Logger` where you change it.
    @inlinable public subscript(metadataKey _: String) -> Logger.Metadata.Value? {
        get {
            nil
        }
        set {}
    }

    /// Get or set the entire metadata storage as a dictionary.
    @inlinable public var metadata: Logger.Metadata {
        get {
            [:]
        }
        set {}
    }

    /// Get or set the log level configured for this `Logger`.
    ///
    /// > Note: Changing the log level threshold for a logger only affects the instance of the `Logger` where you change it.
    /// > It is acceptable for logging backends to have some form of global log level override
    /// > that affects multiple or even all loggers. This means a change in `logLevel` to one `Logger` might in
    /// > certain cases have no effect.
    @inlinable public var logLevel: Logger.Level {
        get {
            .critical
        }
        set {}
    }
}
