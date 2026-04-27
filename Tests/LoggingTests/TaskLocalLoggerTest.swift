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

import Testing

@testable import Logging

struct TaskLocalLoggerTest {
    // MARK: - Binding a logger

    @Test func bindLogger() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        withLogger(logger) { logger in
            logger.info("bound")
        }

        logging.history.assertExist(level: .info, message: "bound")
    }

    @Test func bindLoggerAsyncReturning() async {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        let result = await withLogger(logger) { logger -> Int in
            await Task.yield()
            logger.info("computing")
            return 42
        }

        #expect(result == 42)
        logging.history.assertExist(level: .info, message: "computing")
    }

    /// The bind overload replaces the task-local logger; accumulated metadata from an
    /// enclosing `withLogger(mergingMetadata:)` scope is intentionally not carried over.
    @Test func bindReplacesAccumulatedMetadata() {
        let logging1 = TestLogging()
        let logging2 = TestLogging()
        let root = Logger(label: "root", factory: { logging1.make(label: $0) })
        let other = Logger(label: "other", factory: { logging2.make(label: $0) })

        withLogger(root) { _ in
            withLogger(mergingMetadata: ["request.id": "r1"]) { _ in
                withLogger(other) { inner in
                    inner.info("no request.id")
                }
            }
        }

        let entry = logging2.history.entries.first { $0.message == "no request.id" }
        #expect(entry?.metadata?["request.id"] == nil)
    }

    // MARK: - Modifying the current logger

    @Test func mergeMetadata() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        withLogger(logger) { _ in
            withLogger(mergingMetadata: ["key": "value"]) { logger in
                logger.info("merged")
            }
        }

        logging.history.assertExist(level: .info, message: "merged", metadata: ["key": "value"])
    }

    @Test func overrideLogLevel() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        withLogger(logger) { _ in
            withLogger(logLevel: .warning) { logger in
                logger.debug("suppressed")
                logger.warning("emitted")
            }
        }

        logging.history.assertNotExist(level: .debug, message: "suppressed")
        logging.history.assertExist(level: .warning, message: "emitted")
    }

    @Test func nestedMetadataAccumulates() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        withLogger(logger) { _ in
            withLogger(mergingMetadata: ["level1": "first"]) { _ in
                withLogger(mergingMetadata: ["level2": "second"]) { logger in
                    logger.info("inner")
                }
            }
        }

        logging.history.assertExist(
            level: .info,
            message: "inner",
            metadata: ["level1": "first", "level2": "second"]
        )
    }

    @Test func innerMetadataOverridesOuter() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        withLogger(logger) { _ in
            withLogger(mergingMetadata: ["key": "outer"]) { _ in
                withLogger(mergingMetadata: ["key": "inner"]) { logger in
                    logger.info("test")
                }
            }
        }

        logging.history.assertExist(level: .info, message: "test", metadata: ["key": "inner"])
    }

    /// `withLogger(label:)` rebrands the current logger but inherits metadata from the
    /// enclosing scope — the pattern a library wants when it logs under its own label
    /// while the caller's `request.id` and friends come along. The rebrand must also
    /// preserve the handler's log level and any base metadata the handler carried before
    /// the outer `withLogger` scope (i.e. metadata that isn't merged via a scope).
    @Test func labelRebrandsKeepingMetadata() {
        let logging = TestLogging()
        var logger = Logger(label: "app", factory: { logging.make(label: $0) })
        logger.logLevel = .warning
        logger[metadataKey: "app.version"] = "1.0"  // base metadata on the handler

        withLogger(logger) { _ in
            withLogger(mergingMetadata: ["request.id": "r1"]) { _ in
                withLogger(label: "postgres-client") { libraryLogger in
                    #expect(libraryLogger.label == "postgres-client")
                    #expect(libraryLogger.logLevel == .warning)
                    libraryLogger.info("should not appear (below log level)")
                    libraryLogger.warning("Executing query")
                }
            }
        }

        logging.history.assertNotExist(level: .info, message: "should not appear (below log level)")

        let entry = logging.history.entries.first { $0.message == "Executing query" }
        #expect(entry?.metadata?["request.id"] == "r1")
        #expect(entry?.metadata?["app.version"] == "1.0")
    }

    /// `withLogger(handler:)` routes logs to a different handler for the scope — the
    /// canonical use is swapping in an in-memory handler to capture logs for assertions
    /// in a test.
    @Test func handlerSwapsForScope() {
        let outer = TestLogging()
        let inner = TestLogging()
        let appLogger = Logger(label: "app", factory: { outer.make(label: $0) })

        withLogger(appLogger) { _ in
            for _ in outer.history.entries {}  // touch outer so we can see the drift
            withLogger(handler: inner.make(label: "captured"), mergingMetadata: ["case": "test"]) { scoped in
                scoped.info("emitted under inner handler")
            }
            appLogger.info("back under outer")
        }

        inner.history.assertExist(
            level: .info,
            message: "emitted under inner handler",
            metadata: ["case": "test"]
        )
        inner.history.assertNotExist(level: .info, message: "back under outer")
        outer.history.assertExist(level: .info, message: "back under outer")
        outer.history.assertNotExist(level: .info, message: "emitted under inner handler")
    }

    @Test func siblingScopesAreIsolated() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        withLogger(logger) { _ in
            withLogger(mergingMetadata: ["a": "1"]) { logger in
                logger.info("first")
            }
            withLogger(mergingMetadata: ["b": "2"]) { logger in
                logger.info("second")
            }
        }

        let second = logging.history.entries.first { $0.message == "second" }
        #expect(second?.metadata?["a"] == nil)
        #expect(second?.metadata?["b"] == "2")
    }

    // MARK: - Async propagation and task isolation

    @Test func contextPreservedAcrossAwait() async throws {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        try await withLogger(logger) { _ in
            try await withLogger(mergingMetadata: ["request": "123"]) { logger in
                logger.info("before await")
                await Task.yield()
                logger.info("after await")
            }
        }

        logging.history.assertExist(level: .info, message: "before await", metadata: ["request": "123"])
        logging.history.assertExist(level: .info, message: "after await", metadata: ["request": "123"])
    }

    @Test func childTaskInheritsContextDetachedDoesNot() async {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        await withLogger(logger) { _ in
            await withLogger(mergingMetadata: ["parent": "value"]) { _ in
                await Task {
                    Logger.current.info("child")
                }.value
                await Task.detached {
                    Logger.current.info("detached")
                }.value
            }
        }

        logging.history.assertExist(level: .info, message: "child", metadata: ["parent": "value"])
        // Detached task uses the NoOp fallback and does not reach our TestLogging.
        logging.history.assertNotExist(level: .info, message: "detached")
    }

    @Test func concurrentTasksHaveIndependentContext() async {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        await withLogger(logger) { _ in
            await withLogger(mergingMetadata: ["context": "parent"]) { _ in
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        withLogger(mergingMetadata: ["task": "1"]) { logger in
                            logger.info("task 1")
                        }
                    }
                    group.addTask {
                        withLogger(mergingMetadata: ["task": "2"]) { logger in
                            logger.info("task 2")
                        }
                    }
                }
            }
        }

        logging.history.assertExist(
            level: .info,
            message: "task 1",
            metadata: ["task": "1", "context": "parent"]
        )
        logging.history.assertExist(
            level: .info,
            message: "task 2",
            metadata: ["task": "2", "context": "parent"]
        )
    }

    @Test func asyncLetInheritsContext() async {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        func observedScope() async -> String? {
            Logger.current.handler.metadata["scope"]?.description
        }

        await withLogger(logger) { _ in
            await withLogger(mergingMetadata: ["scope": "parent"]) { _ in
                async let inherited = observedScope()
                let observed = await inherited
                #expect(observed == "parent")
            }
        }
    }

    // MARK: - Error propagation

    @Test func bindPropagatesThrow() {
        struct TestError: Error {}
        #expect(throws: TestError.self) {
            try withLogger(Logger(label: "t")) { _ in
                throw TestError()
            }
        }
    }

    @Test func modifyAsyncPropagatesThrow() async {
        struct TestError: Error {}
        await #expect(throws: TestError.self) {
            try await withLogger(mergingMetadata: ["k": "v"]) { _ in
                throw TestError()
            }
        }
    }

    // MARK: - Fallback behavior

    @Test func fallbackIsNoOpWithoutBootstrap() {
        // The fallback logger carries the canonical label whether it's bootstrapped or NoOp.
        // (Metadata behavior under NoOp is not directly observable and depends on whether
        // any earlier test bootstrapped the LoggingSystem.)
        withLogger(mergingMetadata: ["key": "value"]) { logger in
            #expect(logger.label == "task-local-fallback")
        }
    }

    // MARK: - Real-world patterns

    @Test func libraryReadsCurrentWithoutLoggerParameter() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        struct DatabaseClient {
            func query(_ sql: String) {
                Logger.current.debug("query", metadata: ["sql": "\(sql)"])
            }
        }

        withLogger(logger) { _ in
            withLogger(mergingMetadata: ["request.id": "123"]) { _ in
                DatabaseClient().query("SELECT 1")
            }
        }

        logging.history.assertExist(
            level: .debug,
            message: "query",
            metadata: ["request.id": "123", "sql": "SELECT 1"]
        )
    }

    // MARK: - Stress

    @Test func deeplyNestedScopes() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        func nest(depth: Int) {
            if depth == 0 {
                Logger.current.info("bottom")
                return
            }
            withLogger(mergingMetadata: ["d-\(depth)": "\(depth)"]) { _ in
                nest(depth: depth - 1)
            }
        }

        withLogger(logger) { _ in
            nest(depth: 20)
        }

        let entry = logging.history.entries.first { $0.message == "bottom" }
        #expect(entry?.metadata?.count == 20)
    }
}
