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

import InMemoryLogging
import Logging
import Testing

struct MultiplexProviderRegressionTests {
    @Test(arguments: [1, 2])
    func constructorProviderReachesEverySink(handlerCount: Int) {
        let sinks = (0..<handlerCount).map { _ in InMemoryLogHandler() }
        let handler = MultiplexLogHandler(sinks, metadataProvider: .init { ["trace-id": "123"] })
        let logger = Logger(label: "test", factory: { _ in handler })
        #expect(logger.metadataProvider?.get()["trace-id"] == "123")
        logger.info("hello")
        for sink in sinks {
            #expect(sink.entries.count == 1)
            #expect(sink.entries.first?.metadata["trace-id"] == "123")
        }
    }

    @Test func constructorProviderLayersBetweenChildAndExplicitMetadata() {
        var sink = InMemoryLogHandler()
        sink.metadataProvider = .init { ["child": "kept", "shared": "child"] }
        let handler = MultiplexLogHandler(
            [sink],
            metadataProvider: .init {
                ["outer": "kept", "shared": "outer"]
            }
        )
        let logger = Logger(label: "test", factory: { _ in handler })
        logger.info("provided")
        logger.info("explicit", metadata: ["shared": "explicit"])
        #expect(sink.entries.first?.metadata == ["child": "kept", "outer": "kept", "shared": "outer"])
        #expect(sink.entries.last?.metadata == ["child": "kept", "outer": "kept", "shared": "explicit"])
    }

    @Test(arguments: [1, 2])
    func settingProviderReplacesConstructorProvider(handlerCount: Int) {
        let sinks = (0..<handlerCount).map { _ in InMemoryLogHandler() }
        let handler = MultiplexLogHandler(sinks, metadataProvider: .init { ["trace-id": "constructor"] })
        var logger = Logger(label: "test", factory: { _ in handler })

        logger.handler.metadataProvider = .init { ["trace-id": "replaced"] }
        #expect(logger.metadataProvider?.get() == ["trace-id": "replaced"])
        logger.info("replaced")

        logger.handler.metadataProvider = nil
        #expect(logger.metadataProvider == nil)
        logger.info("cleared")

        for sink in sinks {
            #expect(sink.entries.map(\.metadata) == [["trace-id": "replaced"], [:]])
        }
    }

    @Test func settingProviderReachesHandlersWithoutProviderSupport() {
        let sink = InMemoryLogHandler()
        var handler = MultiplexLogHandler(
            [HandlerWithoutProviderSupport(sink: sink)],
            metadataProvider: .init { ["trace-id": "constructor"] }
        )
        handler.metadataProvider = .init { ["trace-id": "replaced"] }
        let logger = Logger(label: "test", factory: { _ in handler })
        logger.info("hello")
        // Debug builds may also record a one-time warning about the unsupported provider.
        #expect(sink.entries.filter { $0.message == "hello" }.map(\.metadata) == [["trace-id": "replaced"]])
    }
}

/// Uses the default `metadataProvider` implementation, so it ignores providers set on it.
private struct HandlerWithoutProviderSupport: LogHandler {
    let sink: InMemoryLogHandler
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .info

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { self.metadata[key] }
        set { self.metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        self.sink.log(event: event)
    }
}
