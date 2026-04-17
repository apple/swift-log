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
    /// Merge additional metadata into this logger, returning a new instance.
    ///
    /// - Parameter additionalMetadata: The metadata dictionary to merge. Values in `additionalMetadata`
    ///   will override existing values for the same keys.
    /// - Returns: A new `Logger` instance with the merged metadata.
    @inlinable
    package func with(additionalMetadata: Logger.Metadata) -> Logger {
        var newLogger = self
        newLogger.handler.metadata.merge(additionalMetadata) { _, new in new }
        return newLogger
    }

    /// Update this logger's optional properties in place.
    @inlinable
    package mutating func update(
        logLevel: Logger.Level? = nil,
        mergingMetadata: Logger.Metadata? = nil,
        metadataProvider: Logger.MetadataProvider? = nil
    ) {
        if let logLevel {
            self.logLevel = logLevel
        }
        if let mergingMetadata {
            self.handler.metadata.merge(mergingMetadata) { _, new in new }
        }
        if let metadataProvider {
            self.handler.metadataProvider = metadataProvider
        }
    }
}

// MARK: - withLogger() free functions for task-local logger

// Note on throws(Failure) and Sendable:
// The public API uses `rethrows` instead of `throws(Failure)` and does not constrain `Result: Sendable`
// on async variants. This is because the underlying `TaskLocal.withValue` API uses untyped throws,
// making it impossible to propagate typed throws through the closure chain. Once the standard library
// adopts typed throws on TaskLocal, these signatures can be updated.

// MARK: Bind a specific logger

/// Runs the given closure with a logger bound to the task-local context.
///
/// This is the primary way to set up a task-local logger. All code within the closure can access the logger
/// via `Logger.current` without explicit parameter passing.
///
/// ## Example: Setting up task-local logger at application entry point
///
/// ```swift
/// func main() async {
///     let handler = StreamLogHandler.standardOutput(label: "app")
///     let logger = Logger(label: "app", handler: handler)
///     await withLogger(logger) { logger in
///         logger.info("Application started")
///         await handleRequests()  // All nested code has access via Logger.current
///     }
/// }
/// ```
///
/// ## Example: Bridging from explicit logger to task-local
///
/// ```swift
/// func handleRequest(logger: Logger) async {
///     await withLogger(logger) { _ in
///         await processRequest()  // Now uses Logger.current
///     }
/// }
/// ```
///
/// - Parameters:
///   - logger: The logger to bind to the task-local context.
///   - operation: The closure to run with the logger bound.
/// - Returns: The value returned by the closure.
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

/// Runs the given async closure with a logger bound to the task-local context.
///
/// Async variant of the synchronous `withLogger`. See that function for detailed documentation.
///
/// - Parameters:
///   - logger: The logger to bind to the task-local context.
///   - operation: The async closure to run with the logger bound.
/// - Returns: The value returned by the closure.
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

// MARK: Modify current task-local logger

/// Runs the given closure with a modified task-local logger.
///
/// This function modifies the current task-local logger by specifying any combination of log level,
/// metadata, and metadata provider. Only the specified parameters modify the current logger; `nil` parameters
/// leave the current values unchanged.
///
/// ## Example: Progressive metadata accumulation
///
/// ```swift
/// withLogger(mergingMetadata: ["request.id": "\(request.id)"]) { logger in
///     logger.info("Handling request")
///
///     withLogger(mergingMetadata: ["user.id": "\(user.id)"]) { logger in
///         logger.info("Authenticated")  // Has both request.id and user.id
///     }
/// }
/// ```
///
/// ## Example: Changing log level in a scope
///
/// ```swift
/// withLogger(logLevel: .debug) { logger in
///     logger.debug("Detailed debugging information")
/// }
/// ```
///
/// > Important: Task-local values are **not** inherited by detached tasks created with `Task.detached`.
/// > If you need logger context in a detached task, capture the logger explicitly or use structured
/// > concurrency (`async let`, `withTaskGroup`, etc.) instead.
///
/// - Parameters:
///   - logLevel: Optional log level. If provided, sets this log level on the logger.
///   - mergingMetadata: Optional metadata to merge with the current logger's metadata.
///   - metadataProvider: Optional metadata provider to set on the logger.
///   - operation: The closure to run with the modified task-local logger.
/// - Returns: The value returned by the closure.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
public func withLogger<Result>(
    logLevel: Logger.Level? = nil,
    mergingMetadata: Logger.Metadata? = nil,
    metadataProvider: Logger.MetadataProvider? = nil,
    _ operation: (Logger) throws -> Result
) rethrows -> Result {
    var logger = Logger.current
    logger.update(logLevel: logLevel, mergingMetadata: mergingMetadata, metadataProvider: metadataProvider)
    return try Logger.withTaskLocalLogger(logger) {
        try operation(logger)
    }
}

/// Runs the given async closure with a modified task-local logger.
///
/// Async variant. See the synchronous `withLogger(logLevel:mergingMetadata:metadataProvider:_:)`
/// for detailed documentation.
///
/// - Parameters:
///   - logLevel: Optional log level. If provided, sets this log level on the logger.
///   - mergingMetadata: Optional metadata to merge with the current logger's metadata.
///   - metadataProvider: Optional metadata provider to set on the logger.
///   - operation: The async closure to run with the modified task-local logger.
/// - Returns: The value returned by the closure.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@inlinable
nonisolated(nonsending)
    public func withLogger<Result>(
        logLevel: Logger.Level? = nil,
        mergingMetadata: Logger.Metadata? = nil,
        metadataProvider: Logger.MetadataProvider? = nil,
        _ operation: nonisolated(nonsending) (Logger) async throws -> Result
    ) async rethrows -> Result
{
    var logger = Logger.current
    logger.update(logLevel: logLevel, mergingMetadata: mergingMetadata, metadataProvider: metadataProvider)
    return try await Logger.withTaskLocalLogger(logger) {
        try await operation(logger)
    }
}
