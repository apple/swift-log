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

import Foundation
import Testing

@testable import Logging

/// Tests for task-local logger functionality.
///
/// These tests demonstrate that task-local storage provides automatic isolation
/// between tasks, enabling concurrent test execution without serialization.
/// Each task maintains its own independent logger context.
struct TaskLocalLoggerTest {
    // MARK: - Basic task-local access

    @Test func withCurrentProvidesDefaultLogger() {
        // Test that withCurrent provides a fallback logger when no context is set
        Logger.withCurrent { logger in
            #expect(logger.label == "task-local-fallback")
        }
    }

    @Test func withCurrentSyncVoid() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        Logger.withCurrent(
            changingHandler: logger.handler,
            mergingMetadata: ["test": "value"]
        ) { logger in
            logger.info("test message")
        }

        logging.history.assertExist(
            level: .info,
            message: "test message",
            metadata: ["test": "value"]
        )
    }

    @Test func withCurrentSyncReturning() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        let result = Logger.withCurrent(
            changingHandler: logger.handler,
            mergingMetadata: ["test": "value"]
        ) { _ in
            logger.info("computing")
            return 42
        }

        #expect(result == 42)
        logging.history.assertExist(level: .info, message: "computing")
    }

    @Test func withCurrentAsyncVoid() async {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        Logger.withCurrent(
            changingHandler: logger.handler,
            mergingMetadata: ["test": "async"]
        ) { logger in
            logger.info("async message")
        }

        logging.history.assertExist(
            level: .info,
            message: "async message",
            metadata: ["test": "async"]
        )
    }

    @Test func withCurrentAsyncReturning() async {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        let result = Logger.withCurrent(
            changingHandler: logger.handler,
            mergingMetadata: ["test": "async"]
        ) { logger in
            logger.info("computing async")
            return "result"
        }

        #expect(result == "result")
        logging.history.assertExist(level: .info, message: "computing async")
    }

    // MARK: - Static Logger.withCurrent() methods

    @Test func staticWithMetadataSyncVoid() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        Logger.withCurrent(
            changingHandler: logger.handler,
            mergingMetadata: ["key": "value"]
        ) { logger in
            logger.info("test")
        }

        logging.history.assertExist(
            level: .info,
            message: "test",
            metadata: ["key": "value"]
        )
    }

    @Test func staticWithMetadataSyncReturning() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        let result = Logger.withCurrent(
            changingHandler: logger.handler,
            mergingMetadata: ["key": "value"]
        ) { _ in
            logger.info("computing")
            return 100
        }

        #expect(result == 100)
        logging.history.assertExist(level: .info, message: "computing")
    }

    @Test func staticWithMetadataAsyncVoid() async {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        Logger.withCurrent(
            changingHandler: logger.handler,
            mergingMetadata: ["async": "true"]
        ) { logger in
            logger.info("async test")
        }

        logging.history.assertExist(
            level: .info,
            message: "async test",
            metadata: ["async": "true"]
        )
    }

    @Test func staticWithMetadataAsyncReturning() async {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        let result = Logger.withCurrent(
            changingHandler: logger.handler,
            mergingMetadata: ["async": "true"]
        ) { logger in
            logger.info("async computing")
            return "async result"
        }

        #expect(result == "async result")
        logging.history.assertExist(level: .info, message: "async computing")
    }

    @Test func staticWithLogLevel() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        Logger.withCurrent(
            changingHandler: logger.handler,
            changingLogLevel: .warning
        ) { logger in
            logger.debug("should not appear")
            logger.warning("should appear")
        }

        logging.history.assertNotExist(level: .debug, message: "should not appear")
        logging.history.assertExist(level: .warning, message: "should appear")
    }

    @Test func staticWithHandler() {
        let logging1 = TestLogging()
        let logging2 = TestLogging()
        let logger = Logger(label: "test", factory: { logging1.make(label: $0) })

        let customHandler = logging2.make(label: "custom")

        Logger.withCurrent(changingHandler: logger.handler) { _ in
            Logger.withCurrent(changingHandler: customHandler) { logger in
                logger.info("custom handler message")
            }
        }

        // Should appear in custom handler (logging2), not default (logging1)
        logging1.history.assertNotExist(level: .info, message: "custom handler message")
        logging2.history.assertExist(level: .info, message: "custom handler message")
    }

    @Test func staticWithMetadataAndLogLevel() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        Logger.withCurrent(
            changingHandler: logger.handler,
            changingLogLevel: .error,
            mergingMetadata: ["combined": "test"]
        ) { logger in
            logger.info("should not appear")
            logger.error("should appear")
        }

        logging.history.assertNotExist(level: .info, message: "should not appear")
        logging.history.assertExist(
            level: .error,
            message: "should appear",
            metadata: ["combined": "test"]
        )
    }

    // MARK: - Metadata accumulation

    @Test func nestedStaticWithAccumulatesMetadata() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        Logger.withCurrent(changingHandler: logger.handler) { _ in
            Logger.withCurrent(mergingMetadata: ["level1": "first"]) { logger in
                logger.info("level 1")

                Logger.withCurrent(mergingMetadata: ["level2": "second"]) { logger in
                    logger.info("level 2")
                }
            }
        }

        logging.history.assertExist(
            level: .info,
            message: "level 1",
            metadata: ["level1": "first"]
        )
        logging.history.assertExist(
            level: .info,
            message: "level 2",
            metadata: ["level1": "first", "level2": "second"]
        )
    }

    @Test func nestedMetadataOverrides() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        Logger.withCurrent(changingHandler: logger.handler) { _ in
            Logger.withCurrent(mergingMetadata: ["key": "original"]) { logger in
                Logger.withCurrent(mergingMetadata: ["key": "override"]) { logger in
                    logger.info("test")
                }
            }
        }

        logging.history.assertExist(
            level: .info,
            message: "test",
            metadata: ["key": "override"]
        )
    }

    // MARK: - Task isolation (enables concurrent tests!)

    @Test func tasksHaveIndependentContext() async {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        await Logger.withCurrent(
            changingHandler: logger.handler,
            mergingMetadata: ["context": "parent"]
        ) { _ in
            await withTaskGroup(of: Void.self) { group in
                // Task 1
                group.addTask {
                    Logger.withCurrent(mergingMetadata: ["task": "1"]) { logger in
                        logger.info("task 1 message")
                    }
                }

                // Task 2
                group.addTask {
                    Logger.withCurrent(mergingMetadata: ["task": "2"]) { logger in
                        logger.info("task 2 message")
                    }
                }

                // Task 3
                group.addTask {
                    Logger.withCurrent { logger in
                        // No context set - uses parent task's logger
                        logger.info("task 3 message")
                    }
                }
            }
        }

        // Each task logged with its own independent metadata
        logging.history.assertExist(
            level: .info,
            message: "task 1 message",
            metadata: ["task": "1", "context": "parent"]
        )
        logging.history.assertExist(
            level: .info,
            message: "task 2 message",
            metadata: ["task": "2", "context": "parent"]
        )
        logging.history.assertExist(
            level: .info,
            message: "task 3 message",
            metadata: ["context": "parent"]
        )
    }

    @Test func childTaskInheritsParentContext() async {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        await Logger.withCurrent(changingHandler: logger.handler) { _ in
            await Logger.withCurrent(mergingMetadata: ["parent": "value"]) { logger in
                logger.info("parent message")

                // Create child task
                await Task {
                    Logger.withCurrent { logger in
                        logger.info("child message")
                    }
                }.value
            }
        }

        // Both parent and child should have the metadata
        logging.history.assertExist(
            level: .info,
            message: "parent message",
            metadata: ["parent": "value"]
        )
        logging.history.assertExist(
            level: .info,
            message: "child message",
            metadata: ["parent": "value"]
        )
    }

    @Test func childTaskCanOverrideContext() async {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        await Logger.withCurrent(changingHandler: logger.handler) { _ in
            await Logger.withCurrent(mergingMetadata: ["parent": "original"]) { logger in
                logger.info("parent")

                // Child overrides context
                await Task {
                    Logger.withCurrent(mergingMetadata: ["parent": "overridden"]) { logger in
                        logger.info("child")
                    }
                }.value

                // Parent context unchanged after child completes
                logger.info("parent again")
            }
        }

        logging.history.assertExist(
            level: .info,
            message: "parent",
            metadata: ["parent": "original"]
        )
        logging.history.assertExist(
            level: .info,
            message: "child",
            metadata: ["parent": "overridden"]
        )
        logging.history.assertExist(
            level: .info,
            message: "parent again",
            metadata: ["parent": "original"]
        )
    }

    // MARK: - Async propagation

    @Test func contextPreservedAcrossAwaitBoundaries() async throws {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        try await Logger.withCurrent(changingHandler: logger.handler) { _ in
            try await Logger.withCurrent(mergingMetadata: ["request": "123"]) { logger in
                logger.info("before await")

                // Simulate async work
                try await Task.sleep(nanoseconds: 1_000_000_000)

                logger.info("after await")
            }
        }

        // Context preserved across await
        logging.history.assertExist(
            level: .info,
            message: "before await",
            metadata: ["request": "123"]
        )
        logging.history.assertExist(
            level: .info,
            message: "after await",
            metadata: ["request": "123"]
        )
    }

    @Test func contextPreservedThroughAsyncFunctions() async {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        func innerAsync() async {
            Logger.withCurrent { logger in
                logger.info("inner function")
            }
        }

        func outerAsync() async {
            Logger.withCurrent { logger in
                logger.info("outer before")
            }

            await innerAsync()

            Logger.withCurrent { logger in
                logger.info("outer after")
            }
        }

        await Logger.withCurrent(changingHandler: logger.handler) { _ in
            await Logger.withCurrent(mergingMetadata: ["flow": "async"]) { logger in
                await outerAsync()
            }
        }

        // All functions see the same context
        logging.history.assertExist(
            level: .info,
            message: "outer before",
            metadata: ["flow": "async"]
        )
        logging.history.assertExist(
            level: .info,
            message: "inner function",
            metadata: ["flow": "async"]
        )
        logging.history.assertExist(
            level: .info,
            message: "outer after",
            metadata: ["flow": "async"]
        )
    }

    // MARK: - Log level modification

    @Test func logLevelFilteringWorks() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        Logger.withCurrent(changingHandler: logger.handler) { _ in
            Logger.withCurrent(changingLogLevel: .warning) { logger in
                logger.trace("trace - should not appear")
                logger.debug("debug - should not appear")
                logger.info("info - should not appear")
                logger.warning("warning - should appear")
                logger.error("error - should appear")
            }
        }

        #expect(logging.history.entries.count == 2)
        logging.history.assertNotExist(level: .trace, message: "trace - should not appear")
        logging.history.assertNotExist(level: .debug, message: "debug - should not appear")
        logging.history.assertNotExist(level: .info, message: "info - should not appear")
        logging.history.assertExist(level: .warning, message: "warning - should appear")
        logging.history.assertExist(level: .error, message: "error - should appear")
    }

    @Test func logLevelCanBeChanged() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        Logger.withCurrent(changingHandler: logger.handler) { _ in
            Logger.withCurrent(changingLogLevel: .error) { logger in
                logger.info("first - should not appear")

                Logger.withCurrent(changingLogLevel: .info) { logger in
                    logger.info("second - should appear")
                }

                logger.info("third - should not appear")
            }
        }

        logging.history.assertNotExist(level: .info, message: "first - should not appear")
        logging.history.assertExist(level: .info, message: "second - should appear")
        logging.history.assertNotExist(level: .info, message: "third - should not appear")
    }

    // MARK: - Instance with() methods

    @Test func withAdditionalMetadata() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        let copied = logger.with(additionalMetadata: ["copied": "metadata"])

        copied.info("test message")

        logging.history.assertExist(
            level: .info,
            message: "test message",
            metadata: ["copied": "metadata"]
        )
    }

    @Test func withLogLevel() {
        let logging = TestLogging()
        var logger = Logger(label: "test", factory: { logging.make(label: $0) })
        logger.logLevel = .error

        // Create a copy and change its log level
        var copied = logger
        copied.logLevel = .debug

        copied.debug("should appear")
        logger.debug("should not appear")

        #expect(logging.history.entries.count == 1)
        logging.history.assertExist(level: .debug, message: "should appear")
    }

    @Test func withHandler() {
        let logging1 = TestLogging()
        let logging2 = TestLogging()
        let logger = Logger(label: "test", factory: { logging1.make(label: $0) })

        // Create a new logger with a different handler instead of using .with(handler:)
        let copied = Logger(label: "copied", factory: { logging2.make(label: $0) })

        logger.info("original")
        copied.info("copied")

        logging1.history.assertExist(level: .info, message: "original")
        logging1.history.assertNotExist(level: .info, message: "copied")

        logging2.history.assertNotExist(level: .info, message: "original")
        logging2.history.assertExist(level: .info, message: "copied")
    }

    @Test func withDoesNotMutateOriginal() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        let copied = logger.with(additionalMetadata: ["key": "value"])

        logger.info("original")
        copied.info("copied")

        // Original should not have the metadata
        logging.history.assertExist(level: .info, message: "original", metadata: nil)
        logging.history.assertExist(
            level: .info,
            message: "copied",
            metadata: ["key": "value"]
        )
    }

    // MARK: - Real-world scenarios

    @Test func requestHandlerPattern() async {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        func processRequest(id: String) async {
            await Logger.withCurrent(mergingMetadata: ["request.id": "\(id)"]) { logger in
                logger.info("Request received")

                await authenticateUser(username: "alice")

                logger.info("Request completed")
            }
        }

        func authenticateUser(username: String) async {
            Logger.withCurrent(mergingMetadata: ["user": "\(username)"]) { logger in
                logger.debug("Authenticating user")
            }
        }

        await Logger.withCurrent(changingHandler: logger.handler) { _ in
            await processRequest(id: "req-123")
        }

        logging.history.assertExist(
            level: .info,
            message: "Request received",
            metadata: ["request.id": "req-123"]
        )
        logging.history.assertExist(
            level: .debug,
            message: "Authenticating user",
            metadata: ["request.id": "req-123", "user": "alice"]
        )
        logging.history.assertExist(
            level: .info,
            message: "Request completed",
            metadata: ["request.id": "req-123"]
        )
    }

    @Test func libraryEntryPointPattern() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        // Library code that doesn't require logger parameter
        struct DatabaseClient {
            func query(_ sql: String) {
                Logger.withCurrent { logger in
                    logger.debug("Executing query", metadata: ["sql": "\(sql)"])
                }
            }
        }

        // Application sets up context
        Logger.withCurrent(changingHandler: logger.handler) { _ in
            Logger.withCurrent(mergingMetadata: ["request.id": "123"]) { logger in
                let db = DatabaseClient()
                db.query("SELECT * FROM users")
            }
        }

        logging.history.assertExist(
            level: .debug,
            message: "Executing query",
            metadata: ["request.id": "123", "sql": "SELECT * FROM users"]
        )
    }
}
