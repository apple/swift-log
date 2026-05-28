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

    /// The modifying `withLogger(metadata:)` overload replaces the inherited metadata
    /// rather than layering — passing `[:]` wipes; passing a fresh dict starts the scope
    /// from a known state.
    @Test func metadataReplacesInherited() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        withLogger(logger) { _ in
            withLogger(mergingMetadata: ["request.id": "r1", "user.id": "u1"]) { _ in
                withLogger(metadata: ["job.id": "j1"]) { scoped in
                    scoped.info("background")
                }
            }
        }

        let entry = logging.history.entries.first { $0.message == "background" }
        #expect(entry?.metadata?["job.id"] == "j1")
        #expect(entry?.metadata?["request.id"] == nil)
        #expect(entry?.metadata?["user.id"] == nil)
    }

    @Test func metadataEmptyDictWipesInherited() {
        let logging = TestLogging()
        let logger = Logger(label: "test", factory: { logging.make(label: $0) })

        withLogger(logger) { _ in
            withLogger(mergingMetadata: ["request.id": "r1"]) { _ in
                withLogger(metadata: [:]) { scoped in
                    scoped.info("wiped")
                }
            }
        }

        let entry = logging.history.entries.first { $0.message == "wiped" }
        #expect(entry?.metadata?.isEmpty ?? true)
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
            withLogger(handler: inner.make(label: "captured"), metadata: ["case": "test"]) { scoped in
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

        await withLogger(logger) { _ in
            await withLogger(mergingMetadata: ["request": "123"]) { logger in
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
        // Detached task starts without a task-local logger and falls back to a freshly
        // constructed `Logger(label: "")`, which doesn't reach our per-test TestLogging.
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
        #expect(throws: TestError.self) {
            try withLogger(mergingMetadata: ["k": "v"]) { _ in
                throw TestError()
            }
        }
    }

    // MARK: - Fallback behavior

    @Test func fallbackUsesEmptyLabel() {
        // Without an active `withLogger` scope, `Logger.current` returns the process-wide
        // unbound default — a `Logger(label: "")` cached from the first time the
        // task-local is touched. The empty label is the diagnostic signal that no
        // `withLogger` scope was set up before the read.
        withLogger(mergingMetadata: ["key": "value"]) { logger in
            #expect(logger.label == "")
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
