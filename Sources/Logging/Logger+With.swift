//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

extension Logger {
    /// Updates optional aspects of this logger in place.
    ///
    /// - `logLevel` — replaces the current log level.
    /// - `mergingMetadata` — merges into the handler's base metadata; keys present in
    ///   `mergingMetadata` override existing values for the same keys.
    @usableFromInline
    internal mutating func update(
        logLevel: Logger.Level? = nil,
        mergingMetadata: Logger.Metadata? = nil
    ) {
        if let logLevel {
            self.logLevel = logLevel
        }
        if let mergingMetadata {
            for (key, value) in mergingMetadata {
                self[metadataKey: key] = value
            }
        }
    }

    /// Returns a copy of this logger rebranded with a new label, preserving the existing
    /// handler (so base metadata, log level, and metadata provider come along).
    @usableFromInline
    internal func relabelled(_ newLabel: String) -> Logger {
        Logger(label: newLabel, self.handler)
    }
}

// MARK: - withLogger() free functions for task-local logger

// Note: `rethrows` (not `throws(Failure)`) and no `Sendable` constraint on `Result` mirror
// the shape of `TaskLocal.withValue` in the current standard library. Revisit if the
// standard library adopts typed throws on `TaskLocal`.

/// Runs `operation` with `logger` bound to the task-local context.
///
/// Code called within `operation` can read the logger via ``Logger/current`` without an
/// explicit parameter. Binding a different logger with this overload **replaces** the
/// current task-local logger; any metadata accumulated by an outer
/// ``withLogger(label:logLevel:mergingMetadata:_:)`` scope is not carried over. Use the
/// modifying overload to layer context instead.
///
/// ```swift
/// let logger = Logger(label: "app")
/// await withLogger(logger) { logger in
///     logger.info("Application started")
///     await handleRequests()  // reads Logger.current
/// }
/// ```
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public func withLogger<Result>(
    _ logger: Logger,
    _ operation: (Logger) throws -> Result
) rethrows -> Result {
    try Logger.withTaskLocalLogger(logger) {
        try operation(logger)
    }
}

/// Async variant of ``withLogger(_:_:)``. See that function for semantics.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
nonisolated(nonsending)
    public func withLogger<Result>(
        _ logger: Logger,
        _ operation: nonisolated(nonsending) (Logger) async throws -> Result
    ) async rethrows -> Result
{
    try await Logger.withTaskLocalLogger(logger) {
        try await operation(logger)
    }
}

/// Runs `operation` with a modified copy of ``Logger/current`` bound to the task-local
/// context. `nil` parameters leave the corresponding aspect unchanged; nested scopes
/// accumulate metadata.
///
/// Unlike ``withLogger(_:_:)``, which **replaces** the task-local logger, this overload
/// **layers on top of** the current one — metadata accumulated by enclosing scopes is
/// preserved.
///
/// - `label` — rebrands the current logger with the given label while keeping the existing
///   handler, metadata, and log level. Useful for library code that wants to emit logs
///   under its own label (for example `"postgres-client"`) while still inheriting the
///   caller's accumulated metadata.
/// - `handler` — replaces the current logger's handler for the scope. Primarily useful in
///   tests to route logs through an `InMemoryLogHandler` or similar, while keeping the
///   caller's label and accumulated metadata.
/// - `logLevel` — replaces the current log level.
/// - `mergingMetadata` — merges into the handler's base metadata; keys present in
///   `mergingMetadata` override existing values for the same keys.
///
/// With no arguments, this overload re-binds ``Logger/current`` unchanged — a convenient
/// way to extract it into a local variable for repeated use inside the closure.
///
/// ```swift
/// withLogger(mergingMetadata: ["request.id": "\(request.id)"]) { logger in
///     logger.info("Handling request")
///     withLogger(mergingMetadata: ["user.id": "\(user.id)"]) { logger in
///         logger.info("Authenticated")  // sees both request.id and user.id
///     }
/// }
/// ```
///
/// When no `withLogger` scope has been set up and no `LoggingSystem` bootstrap has
/// happened, `Logger.current` (and therefore this function) returns a silent no-op
/// fallback — a one-time warning is emitted on stderr the first time this occurs.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public func withLogger<Result>(
    label: String? = nil,
    handler: (any LogHandler)? = nil,
    logLevel: Logger.Level? = nil,
    mergingMetadata: Logger.Metadata? = nil,
    _ operation: (Logger) throws -> Result
) rethrows -> Result {
    var logger = Logger.current
    if let handler {
        logger.handler = handler
    }
    if let label {
        logger = logger.relabelled(label)
    }
    logger.update(logLevel: logLevel, mergingMetadata: mergingMetadata)
    return try Logger.withTaskLocalLogger(logger) {
        try operation(logger)
    }
}

/// Async variant of ``withLogger(label:handler:logLevel:mergingMetadata:_:)``. See that
/// function for semantics.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
nonisolated(nonsending)
    public func withLogger<Result>(
        label: String? = nil,
        handler: (any LogHandler)? = nil,
        logLevel: Logger.Level? = nil,
        mergingMetadata: Logger.Metadata? = nil,
        _ operation: nonisolated(nonsending) (Logger) async throws -> Result
    ) async rethrows -> Result
{
    var logger = Logger.current
    if let handler {
        logger.handler = handler
    }
    if let label {
        logger = logger.relabelled(label)
    }
    logger.update(logLevel: logLevel, mergingMetadata: mergingMetadata)
    return try await Logger.withTaskLocalLogger(logger) {
        try await operation(logger)
    }
}
