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
    /// Create a new logger with additional metadata merged into the existing metadata.
    ///
    /// This method merges the provided metadata with the logger's current metadata,
    /// returning a new logger instance. The original logger is not modified.
    /// This method is more efficient than setting metadata items individually in a loop,
    /// as it triggers copy-on-write only once.
    ///
    /// - Parameter additionalMetadata: The metadata dictionary to merge. Values in `additionalMetadata`
    ///   will override existing values for the same keys.
    /// - Returns: A new `Logger` instance with the merged metadata.
    @inlinable
    package func with(additionalMetadata: Logger.Metadata) -> Logger {
        var newLogger = self
        if additionalMetadata.count == 1 {
            newLogger.handler.metadata[additionalMetadata.first!.key] = additionalMetadata.first!.value
        } else {
            newLogger.handler.metadata.merge(additionalMetadata) { _, new in new }
        }
        return newLogger
    }
}

// MARK: - Static withCurrent() methods for task-local logger

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Logger {
    /// Modify or initialize the task-local logger with optional overrides.
    ///
    /// This method allows you to modify the current task-local logger or create a new one
    /// by specifying any combination of label, handler, log level, metadata, and metadata provider.
    /// Only the specified parameters will be modified; nil parameters leave the current values unchanged.
    ///
    /// > Important: Task-local values are **not** inherited by detached tasks created with `Task.detached`.
    /// > If you need logger context in a detached task, capture the logger explicitly or use structured
    /// > concurrency (`async let`, `withTaskGroup`, etc.) instead.
    ///
    /// Example:
    /// ```swift
    /// // Initialize task-local logger at application entry point
    /// Logger.withCurrent(
    ///     changingLabel: "request-handler",
    ///     changingHandler: myHandler,
    ///     changingLogLevel: .info
    /// ) { logger in
    ///     logger.info("Request started")
    ///     // All subsequent code has access to this logger via Logger.current
    /// }
    ///
    /// // Add metadata to existing task-local logger
    /// Logger.withCurrent(mergingMetadata: ["request.id": "123"]) { logger in
    ///     logger.info("Processing request")
    /// }
    ///
    /// // Change log level temporarily
    /// Logger.withCurrent(changingLogLevel: .debug) { logger in
    ///     logger.debug("Detailed debugging info")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - changingLabel: Optional label for the logger. If provided without `changingHandler`, reuses the current task-local logger's handler.
    ///   - changingHandler: Optional log handler. If provided, uses this handler for the logger.
    ///   - changingLogLevel: Optional log level. If provided, sets this log level on the logger.
    ///   - mergingMetadata: Optional metadata to merge with the current logger's metadata.
    ///   - changingMetadataProvider: Optional metadata provider to set on the logger.
    ///   - body: The closure to execute with the modified task-local logger.
    /// - Returns: The value returned by the closure.
    @discardableResult
    @inlinable
    public static func withCurrent<Return, Failure: Error>(
        changingLabel: String? = nil,
        changingHandler: (any LogHandler)? = nil,
        changingLogLevel: Logger.Level? = nil,
        mergingMetadata: Metadata? = nil,
        changingMetadataProvider: MetadataProvider? = nil,
        _ body: (Logger) throws(Failure) -> Return
    ) rethrows -> Return {
        // Start with current logger or create a new one
        var logger: Logger
        if let label = changingLabel {
            // If label is provided, use provided handler or reuse current handler
            let handler = changingHandler ?? Logger.current.handler
            logger = Logger(label: label, handler)
        } else if let handler = changingHandler {
            // If only handler is provided, use current label
            logger = Logger(label: Logger.current.label, handler)
        } else {
            // Otherwise, start with current logger
            logger = Logger.current
        }

        // Apply optional modifications directly
        if let logLevel = changingLogLevel {
            logger.logLevel = logLevel
        }
        if let metadata = mergingMetadata {
            // Inline metadata merging logic
            if metadata.count == 1 {
                logger.handler.metadata[metadata.first!.key] = metadata.first!.value
            } else {
                logger.handler.metadata.merge(metadata) { _, new in new }
            }
        }
        if let metadataProvider = changingMetadataProvider {
            logger.handler.metadataProvider = metadataProvider
        }

        return try Logger.withTaskLocalLogger(logger) {
            try body(logger)
        }
    }

    /// Modify or initialize the task-local logger with optional overrides (async version).
    ///
    /// This method allows you to modify the current task-local logger or create a new one
    /// by specifying any combination of label, handler, log level, metadata, and metadata provider.
    /// Only the specified parameters will be modified; nil parameters leave the current values unchanged.
    ///
    /// > Important: Task-local values are **not** inherited by detached tasks created with `Task.detached`.
    /// > If you need logger context in a detached task, capture the logger explicitly or use structured
    /// > concurrency (`async let`, `withTaskGroup`, etc.) instead.
    ///
    /// Example:
    /// ```swift
    /// // Initialize task-local logger at application entry point
    /// await Logger.withCurrent(
    ///     changingLabel: "request-handler",
    ///     changingHandler: myHandler,
    ///     changingLogLevel: .info
    /// ) { logger in
    ///     logger.info("Request started")
    ///     await processRequest()
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - changingLabel: Optional label for the logger. If provided without `changingHandler`, reuses the current task-local logger's handler.
    ///   - changingHandler: Optional log handler. If provided, uses this handler for the logger.
    ///   - changingLogLevel: Optional log level. If provided, sets this log level on the logger.
    ///   - mergingMetadata: Optional metadata to merge with the current logger's metadata.
    ///   - changingMetadataProvider: Optional metadata provider to set on the logger.
    ///   - body: The async closure to execute with the modified task-local logger.
    /// - Returns: The value returned by the closure.
    @discardableResult
    @inlinable
    public static func withCurrent<Return, Failure: Error>(
        changingLabel: String? = nil,
        changingHandler: (any LogHandler)? = nil,
        changingLogLevel: Logger.Level? = nil,
        mergingMetadata: Metadata? = nil,
        changingMetadataProvider: MetadataProvider? = nil,
        _ body: (Logger) async throws(Failure) -> Return
    ) async rethrows -> Return {
        // Start with current logger or create a new one
        var logger: Logger
        if let label = changingLabel {
            // If label is provided, use provided handler or reuse current handler
            let handler = changingHandler ?? Logger.current.handler
            logger = Logger(label: label, handler)
        } else if let handler = changingHandler {
            // If only handler is provided, use current label
            logger = Logger(label: Logger.current.label, handler)
        } else {
            // Otherwise, start with current logger
            logger = Logger.current
        }

        // Apply optional modifications directly
        if let logLevel = changingLogLevel {
            logger.logLevel = logLevel
        }
        if let metadata = mergingMetadata {
            // Inline metadata merging logic
            if metadata.count == 1 {
                logger.handler.metadata[metadata.first!.key] = metadata.first!.value
            } else {
                logger.handler.metadata.merge(metadata) { _, new in new }
            }
        }
        if let metadataProvider = changingMetadataProvider {
            logger.handler.metadataProvider = metadataProvider
        }

        return try await Logger.withTaskLocalLogger(logger) {
            try await body(logger)
        }
    }

    /// Override the task-local logger with a specific logger instance.
    ///
    /// This method is specifically for crossing boundaries from explicit logger usage to task-local usage.
    /// It completely replaces the current task-local logger with the provided logger.
    ///
    /// > Important: Task-local values are **not** inherited by detached tasks created with `Task.detached`.
    /// > If you need logger context in a detached task, capture the logger explicitly or use structured
    /// > concurrency (`async let`, `withTaskGroup`, etc.) instead.
    ///
    /// Example:
    /// ```swift
    /// // You have an explicit logger being passed around
    /// func handleRequest(logger: Logger) {
    ///     Logger.withCurrent(overridingLogger: logger) { _ in
    ///         // Now all nested code can use Logger.current
    ///         processRequest()
    ///     }
    /// }
    ///
    /// func processRequest() {
    ///     Logger.current.info("Processing")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - overridingLogger: The logger to set as the task-local logger.
    ///   - body: The closure to execute with the overriding task-local logger.
    /// - Returns: The value returned by the closure.
    @discardableResult
    @inlinable
    public static func withCurrent<Return, Failure: Error>(
        overridingLogger: Logger,
        _ body: (Logger) throws(Failure) -> Return
    ) rethrows -> Return {
        try Logger.withTaskLocalLogger(overridingLogger) {
            try body(overridingLogger)
        }
    }

    /// Override the task-local logger with a specific logger instance (async version).
    ///
    /// This method is specifically for crossing boundaries from explicit logger usage to task-local usage.
    /// It completely replaces the current task-local logger with the provided logger.
    ///
    /// > Important: Task-local values are **not** inherited by detached tasks created with `Task.detached`.
    /// > If you need logger context in a detached task, capture the logger explicitly or use structured
    /// > concurrency (`async let`, `withTaskGroup`, etc.) instead.
    ///
    /// Example:
    /// ```swift
    /// // You have an explicit logger being passed around
    /// func handleRequest(logger: Logger) async {
    ///     await Logger.withCurrent(overridingLogger: logger) { _ in
    ///         // Now all nested code can use Logger.current
    ///         await processRequest()
    ///     }
    /// }
    ///
    /// func processRequest() async {
    ///     Logger.current.info("Processing")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - overridingLogger: The logger to set as the task-local logger.
    ///   - body: The async closure to execute with the overriding task-local logger.
    /// - Returns: The value returned by the closure.
    @discardableResult
    @inlinable
    public static func withCurrent<Return, Failure: Error>(
        overridingLogger: Logger,
        _ body: (Logger) async throws(Failure) -> Return
    ) async rethrows -> Return {
        try await Logger.withTaskLocalLogger(overridingLogger) {
            try await body(overridingLogger)
        }
    }
}
