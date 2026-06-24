//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// MARK: - withLogger() free functions for task-local logger

/// Runs `operation` with `logger` bound to the task-local context.
///
/// Code called within `operation` can read the logger via ``Logger/current`` without an
/// explicit parameter. Binding a different logger with this overload **replaces** the
/// current task-local logger; any metadata accumulated by an outer
/// ``withLogger(mergingMetadata:_:)-(_,(Logger)(Failure)->Result)`` or
/// ``withLogger(logLevel:handler:metadata:_:)-(_,_,_,(Logger)(Failure)->Result)``
/// scope is not carried over. Use the modifying overloads to layer or replace aspects
/// of the current logger instead.
///
/// This overload is the application-bootstrap binding mechanism: pass a `Logger`
/// constructed via ``Logger/init(label:)`` at your application entry point. Because
/// ``Logger/init(label:)`` consults `LoggingSystem.factory`, the constructed `Logger`
/// only carries a useful handler once ``LoggingSystem/bootstrap(_:)`` has been called.
/// For mid-call-tree backend swaps that should work without bootstrap (tests, scoped
/// routing), use ``withLogger(logLevel:handler:metadata:_:)-(_,_,_,(Logger)(Failure)->Result)``
/// instead — it modifies
/// the current logger's handler in place without constructing a new one.
///
/// ```swift
/// let logger = Logger(label: "app")
/// await withLogger(logger) { logger in
///     logger.info("Application started")
///     await handleRequests()  // reads Logger.current
/// }
/// ```
///
/// - Parameters:
///   - logger: The logger to bind for the duration of `operation`.
///   - operation: The closure to run with `logger` bound. Receives `logger` as a
///     parameter so the body does not need to re-read ``Logger/current``.
/// - Returns: The value returned by `operation`.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public func withLogger<Result, Failure: Error>(
    _ logger: Logger,
    _ operation: (Logger) throws(Failure) -> Result
) throws(Failure) -> Result {
    do {
        return try Logger.withTaskLocalLogger(logger) {
            try operation(logger)
        }
    } catch {
        throw error as! Failure
    }
}

/// Runs `operation` with `logger` bound to the task-local context.
///
/// Code called within `operation` can read the logger via ``Logger/current`` without an
/// explicit parameter. Binding a different logger with this overload **replaces** the
/// current task-local logger; any metadata accumulated by an outer
/// ``withLogger(mergingMetadata:_:)-(_,(Logger)(Failure)->Result)`` or
/// ``withLogger(logLevel:handler:metadata:_:)-(_,_,_,(Logger)(Failure)->Result)``
/// scope is not carried over. Use the modifying overloads to layer or replace aspects
/// of the current logger instead.
///
/// This overload is the application-bootstrap binding mechanism: pass a `Logger`
/// constructed via ``Logger/init(label:)`` at your application entry point. Because
/// ``Logger/init(label:)`` consults `LoggingSystem.factory`, the constructed `Logger`
/// only carries a useful handler once ``LoggingSystem/bootstrap(_:)`` has been called.
/// For mid-call-tree backend swaps that should work without bootstrap (tests, scoped
/// routing), use ``withLogger(logLevel:handler:metadata:_:)-(_,_,_,(Logger)(Failure)->Result)``
/// instead — it modifies
/// the current logger's handler in place without constructing a new one.
///
/// ```swift
/// let logger = Logger(label: "app")
/// await withLogger(logger) { logger in
///     logger.info("Application started")
///     await handleRequests()  // reads Logger.current
/// }
/// ```
///
/// - Parameters:
///   - logger: The logger to bind for the duration of `operation`.
///   - operation: The async closure to run with `logger` bound. Receives `logger` as a
///     parameter so the body does not need to re-read ``Logger/current``.
/// - Returns: The value returned by `operation`.
#if compiler(>=6.2)
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public nonisolated(nonsending) func withLogger<Result, Failure: Error>(
    _ logger: Logger,
    _ operation: nonisolated(nonsending) (Logger) async throws(Failure) -> Result
) async throws(Failure) -> Result {
    do {
        return try await Logger.withTaskLocalLogger(logger) {
            try await operation(logger)
        }
    } catch {
        throw error as! Failure
    }
}
#else
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public func withLogger<Result, Failure: Error>(
    _ logger: Logger,
    isolation: isolated (any Actor)? = #isolation,
    _ operation: (Logger) async throws(Failure) -> Result,
) async throws(Failure) -> Result {
    do {
        return try await Logger.withTaskLocalLogger(logger, isolation: isolation) {
            try await operation(logger)
        }
    } catch {
        throw error as! Failure
    }
}
#endif

/// Runs `operation` with a copy of ``Logger/current`` that has `metadata` **layered on
/// top of** the inherited base metadata. Keys present in `metadata` override existing
/// keys with the same name. Other aspects (handler, log level, base metadata not in
/// `metadata`) are preserved.
///
/// Use this overload at request boundaries and any point where context should
/// accumulate. Nested ``withLogger(mergingMetadata:_:)-(_,(Logger)(Failure)->Result)`` scopes
/// layer on top of each
/// other.
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
/// - Parameters:
///   - metadata: Metadata keys merged onto the inherited base metadata for the scope.
///     Keys override existing values with the same name.
///   - operation: The closure to run with the merged logger bound. Receives the
///     merged logger as a parameter.
/// - Returns: The value returned by `operation`.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public func withLogger<Result, Failure: Error>(
    mergingMetadata metadata: @autoclosure () -> Logger.Metadata,
    _ operation: (Logger) throws(Failure) -> Result
) throws(Failure) -> Result {
    var logger = Logger.current
    for (key, value) in metadata() {
        logger[metadataKey: key] = value
    }
    do {
        return try Logger.withTaskLocalLogger(logger) {
            try operation(logger)
        }
    } catch {
        throw error as! Failure
    }
}

/// Runs `operation` with a copy of ``Logger/current`` that has `metadata` **layered on
/// top of** the inherited base metadata. Keys present in `metadata` override existing
/// keys with the same name. Other aspects (handler, log level, base metadata not in
/// `metadata`) are preserved.
///
/// Use this overload at request boundaries and any point where context should
/// accumulate. Nested ``withLogger(mergingMetadata:_:)-(_,(Logger)(Failure)->Result)`` scopes
/// layer on top of each
/// other.
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
/// - Parameters:
///   - metadata: Metadata keys merged onto the inherited base metadata for the scope.
///     Keys override existing values with the same name.
///   - operation: The async closure to run with the merged logger bound. Receives the
///     merged logger as a parameter.
/// - Returns: The value returned by `operation`.
#if compiler(>=6.2)
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public nonisolated(nonsending) func withLogger<Result, Failure: Error>(
    mergingMetadata metadata: @autoclosure () -> Logger.Metadata,
    _ operation: nonisolated(nonsending) (Logger) async throws(Failure) -> Result
) async throws(Failure) -> Result {
    var logger = Logger.current
    for (key, value) in metadata() {
        logger[metadataKey: key] = value
    }
    do {
        return try await Logger.withTaskLocalLogger(logger) {
            try await operation(logger)
        }
    } catch {
        throw error as! Failure
    }
}
#else
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public func withLogger<Result, Failure: Error>(
    mergingMetadata metadata: @autoclosure () -> Logger.Metadata,
    isolation: isolated (any Actor)? = #isolation,
    _ operation: (Logger) async throws(Failure) -> Result,
) async throws(Failure) -> Result {
    var logger = Logger.current
    for (key, value) in metadata() {
        logger[metadataKey: key] = value
    }
    do {
        return try await Logger.withTaskLocalLogger(logger, isolation: isolation) {
            try await operation(logger)
        }
    } catch {
        throw error as! Failure
    }
}
#endif

/// Runs `operation` with a copy of ``Logger/current`` whose aspects are **replaced** by
/// the provided arguments. `nil` parameters leave the corresponding aspect unchanged.
///
/// Unlike ``withLogger(mergingMetadata:_:)-(_,(Logger)(Failure)->Result)``, which layers
/// metadata on top of the
/// inherited base, this overload **replaces** the base metadata when `metadata` is
/// non-nil. Pass `metadata: [:]` to wipe the inherited metadata entirely for the scope.
///
/// With no arguments, this overload re-binds ``Logger/current`` unchanged — a convenient
/// way to extract it into a local variable for repeated use inside the closure.
///
/// ```swift
/// withLogger(mergingMetadata: ["request.id": "\(request.id)"]) { _ in
///     // Start a background job with metadata unrelated to the request that scheduled it.
///     withLogger(metadata: ["job.id": "\(job.id)"]) { logger in
///         logger.info("running")  // metadata: job.id only — request.id wiped
///     }
/// }
/// ```
///
/// When no `withLogger` scope has been set up, ``Logger/current`` (and therefore this
/// function) returns the process-wide unbound default — a `Logger(label: "")` cached
/// from the first time the task-local is touched. Bootstrap before reading
/// ``Logger/current`` for predictable backend selection.
///
/// - Parameters:
///   - logLevel: When non-nil, replaces the current log level for the scope. When `nil`,
///     the inherited log level is preserved.
///   - handler: When non-nil, replaces the current logger's handler for the scope.
///     Useful in tests to route logs through an `InMemoryLogHandler` or similar while
///     keeping the caller's label. When `nil`, the inherited handler is preserved.
///   - metadata: When non-nil, replaces the handler's base metadata dictionary for the
///     scope. Pass `[:]` to erase inherited metadata; pass a fresh dictionary to start
///     a scope from a known state. When `nil`, the inherited base metadata is preserved.
///   - operation: The closure to run with the modified logger bound. Receives the
///     modified logger as a parameter.
/// - Returns: The value returned by `operation`.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public func withLogger<Result, Failure: Error>(
    logLevel: Logger.Level? = nil,
    handler: (any LogHandler)? = nil,
    metadata: @autoclosure () -> Logger.Metadata? = nil,
    _ operation: (Logger) throws(Failure) -> Result
) throws(Failure) -> Result {
    var logger = Logger.current
    if let logLevel {
        logger.logLevel = logLevel
    }
    if let handler {
        logger.handler = handler
    }
    if let metadata = metadata() {
        logger.handler.metadata = metadata
    }
    do {
        return try Logger.withTaskLocalLogger(logger) {
            try operation(logger)
        }
    } catch {
        throw error as! Failure
    }
}

/// Runs `operation` with a copy of ``Logger/current`` whose aspects are **replaced** by
/// the provided arguments. `nil` parameters leave the corresponding aspect unchanged.
///
/// Unlike ``withLogger(mergingMetadata:_:)-(_,(Logger)(Failure)->Result)``, which layers
/// metadata on top of the
/// inherited base, this overload **replaces** the base metadata when `metadata` is
/// non-nil. Pass `metadata: [:]` to wipe the inherited metadata entirely for the scope.
///
/// With no arguments, this overload re-binds ``Logger/current`` unchanged — a convenient
/// way to extract it into a local variable for repeated use inside the closure.
///
/// ```swift
/// withLogger(mergingMetadata: ["request.id": "\(request.id)"]) { _ in
///     // Start a background job with metadata unrelated to the request that scheduled it.
///     withLogger(metadata: ["job.id": "\(job.id)"]) { logger in
///         logger.info("running")  // metadata: job.id only — request.id wiped
///     }
/// }
/// ```
///
/// When no `withLogger` scope has been set up, ``Logger/current`` (and therefore this
/// function) returns the process-wide unbound default — a `Logger(label: "")` cached
/// from the first time the task-local is touched. Bootstrap before reading
/// ``Logger/current`` for predictable backend selection.
///
/// - Parameters:
///   - logLevel: When non-nil, replaces the current log level for the scope. When `nil`,
///     the inherited log level is preserved.
///   - handler: When non-nil, replaces the current logger's handler for the scope.
///     Useful in tests to route logs through an `InMemoryLogHandler` or similar while
///     keeping the caller's label. When `nil`, the inherited handler is preserved.
///   - metadata: When non-nil, replaces the handler's base metadata dictionary for the
///     scope. Pass `[:]` to erase inherited metadata; pass a fresh dictionary to start
///     a scope from a known state. When `nil`, the inherited base metadata is preserved.
///   - operation: The async closure to run with the modified logger bound. Receives the
///     modified logger as a parameter.
/// - Returns: The value returned by `operation`.
#if compiler(>=6.2)
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public nonisolated(nonsending) func withLogger<Result, Failure: Error>(
    logLevel: Logger.Level? = nil,
    handler: (any LogHandler)? = nil,
    metadata: @autoclosure () -> Logger.Metadata? = nil,
    _ operation: nonisolated(nonsending) (Logger) async throws(Failure) -> Result
) async throws(Failure) -> Result {
    var logger = Logger.current
    if let logLevel {
        logger.logLevel = logLevel
    }
    if let handler {
        logger.handler = handler
    }
    if let metadata = metadata() {
        logger.handler.metadata = metadata
    }
    do {
        return try await Logger.withTaskLocalLogger(logger) {
            try await operation(logger)
        }
    } catch {
        throw error as! Failure
    }
}
#else
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public func withLogger<Result, Failure: Error>(
    logLevel: Logger.Level? = nil,
    handler: (any LogHandler)? = nil,
    metadata: @autoclosure () -> Logger.Metadata? = nil,
    isolation: isolated (any Actor)? = #isolation,
    _ operation: (Logger) async throws(Failure) -> Result
) async throws(Failure) -> Result {
    var logger = Logger.current
    if let logLevel {
        logger.logLevel = logLevel
    }
    if let handler {
        logger.handler = handler
    }
    if let metadata = metadata() {
        logger.handler.metadata = metadata
    }
    do {
        return try await Logger.withTaskLocalLogger(logger, isolation: isolation) {
            try await operation(logger)
        }
    } catch {
        throw error as! Failure
    }
}
#endif
