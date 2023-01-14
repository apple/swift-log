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
import Foundation
@testable import Logging
import XCTest
#if os(Windows)
import WinSDK
#endif

internal struct TestLogging {
    private let _config = Config() // shared among loggers
    private let recorder = Recorder() // shared among loggers

    func make(label: String) -> LogHandler {
        return TestLogHandler(
            label: label,
            config: self.config,
            recorder: self.recorder,
            metadataProvider: LoggingSystem.metadataProvider
        )
    }

    func makeWithMetadataProvider(label: String, metadataProvider: Logger.MetadataProvider?) -> LogHandler {
        return TestLogHandler(
            label: label,
            config: self.config,
            recorder: self.recorder,
            metadataProvider: metadataProvider
        )
    }

    var config: Config { return self._config }
    var history: History { return self.recorder }
}

internal struct TestLogHandler: LogHandler {
    private let recorder: Recorder
    private let config: Config
    private var logger: Logger // the actual logger

    let label: String
    public var metadataProvider: Logger.MetadataProvider?

    init(label: String, config: Config, recorder: Recorder, metadataProvider: Logger.MetadataProvider?) {
        self.label = label
        self.config = config
        self.recorder = recorder
        self.logger = Logger(label: "test", StreamLogHandler.standardOutput(label: label))
        self.logger.logLevel = .debug
        self.metadataProvider = metadataProvider
    }

    init(label: String, config: Config, recorder: Recorder) {
        self.label = label
        self.config = config
        self.recorder = recorder
        self.logger = Logger(label: "test", StreamLogHandler.standardOutput(label: label))
        self.logger.logLevel = .debug
        self.metadataProvider = LoggingSystem.metadataProvider
    }

    func log(level: Logger.Level,
             message: Logger.Message,
             metadata explicitMetadata: Logger.Metadata?,
             source: String,
             file: String, function: String, line: UInt) {
        // baseline metadata, that was set on handler:
        var metadata = self._metadataSet ? self.metadata : MDC.global.metadata
        // contextual metadata, e.g. from task-locals:
        let contextualMetadata = self.metadataProvider?.get() ?? [:]
        if !contextualMetadata.isEmpty {
            metadata.merge(contextualMetadata, uniquingKeysWith: { _, contextual in contextual })
        }
        // override using any explicit metadata passed for this log statement:
        if let explicitMetadata = explicitMetadata {
            metadata.merge(explicitMetadata, uniquingKeysWith: { _, explicit in explicit })
        }

        self.logger.log(level: level, message, metadata: metadata, source: source, file: file, function: function, line: line)
        self.recorder.record(level: level, metadata: metadata, message: message, source: source)
    }

    private var _logLevel: Logger.Level?
    var logLevel: Logger.Level {
        get {
            // get from config unless set
            return self._logLevel ?? self.config.get(key: self.label)
        }
        set {
            self._logLevel = newValue
        }
    }

    private var _metadataSet = false
    private var _metadata = Logger.Metadata() {
        didSet {
            self._metadataSet = true
        }
    }

    public var metadata: Logger.Metadata {
        get {
            return self._metadata
        }
        set {
            self._metadata = newValue
        }
    }

    // TODO: would be nice to delegate to local copy of logger but StdoutLogger is a reference type. why?
    subscript(metadataKey metadataKey: Logger.Metadata.Key) -> Logger.Metadata.Value? {
        get {
            return self._metadata[metadataKey]
        }
        set {
            self._metadata[metadataKey] = newValue
        }
    }
}

internal class Config {
    private static let ALL = "*"

    private let lock = NSLock()
    private var storage = [String: Logger.Level]()

    func get(key: String) -> Logger.Level {
        return self.get(key) ?? self.get(Config.ALL) ?? Logger.Level.debug
    }

    func get(_ key: String) -> Logger.Level? {
        guard let value = (self.lock.withLock { self.storage[key] }) else {
            return nil
        }
        return value
    }

    func set(key: String = Config.ALL, value: Logger.Level) {
        self.lock.withLock { self.storage[key] = value }
    }

    func clear() {
        self.lock.withLock { self.storage.removeAll() }
    }
}

internal class Recorder: History {
    private let lock = NSLock()
    private var _entries = [LogEntry]()

    func record(level: Logger.Level, metadata: Logger.Metadata?, message: Logger.Message, source: String) {
        return self.lock.withLock {
            self._entries.append(LogEntry(level: level, metadata: metadata, message: message.description, source: source))
        }
    }

    var entries: [LogEntry] {
        return self.lock.withLock { self._entries }
    }
}

internal protocol History {
    var entries: [LogEntry] { get }
}

internal extension History {
    func atLevel(level: Logger.Level) -> [LogEntry] {
        return self.entries.filter { entry in
            level == entry.level
        }
    }

    var trace: [LogEntry] {
        return self.atLevel(level: .debug)
    }

    var debug: [LogEntry] {
        return self.atLevel(level: .debug)
    }

    var info: [LogEntry] {
        return self.atLevel(level: .info)
    }

    var warning: [LogEntry] {
        return self.atLevel(level: .warning)
    }

    var error: [LogEntry] {
        return self.atLevel(level: .error)
    }
}

internal struct LogEntry {
    let level: Logger.Level
    let metadata: Logger.Metadata?
    let message: String
    let source: String
}

extension History {
    #if compiler(>=5.3)
    func assertExist(level: Logger.Level,
                     message: String,
                     metadata: Logger.Metadata? = nil,
                     source: String? = nil,
                     file: StaticString = #file,
                     fileID: String = #fileID,
                     line: UInt = #line) {
        let source = source ?? Logger.currentModule(fileID: "\(fileID)")
        let entry = self.find(level: level, message: message, metadata: metadata, source: source)
        XCTAssertNotNil(entry, "entry not found: \(level), \(source), \(String(describing: metadata)), \(message)",
                        file: file, line: line)
    }

    func assertNotExist(level: Logger.Level,
                        message: String,
                        metadata: Logger.Metadata? = nil,
                        source: String? = nil,
                        file: StaticString = #file,
                        fileID: String = #file,
                        line: UInt = #line) {
        let source = source ?? Logger.currentModule(fileID: "\(fileID)")
        let entry = self.find(level: level, message: message, metadata: metadata, source: source)
        XCTAssertNil(entry, "entry was found: \(level), \(source), \(String(describing: metadata)), \(message)",
                     file: file, line: line)
    }

    #else
    func assertExist(level: Logger.Level,
                     message: String,
                     metadata: Logger.Metadata? = nil,
                     source: String? = nil,
                     file: StaticString = #file,
                     line: UInt = #line) {
        let source = source ?? Logger.currentModule(filePath: "\(file)")
        let entry = self.find(level: level, message: message, metadata: metadata, source: source)
        XCTAssertNotNil(entry, "entry not found: \(level), \(source), \(String(describing: metadata)), \(message)",
                        file: file, line: line)
    }

    func assertNotExist(level: Logger.Level,
                        message: String,
                        metadata: Logger.Metadata? = nil,
                        source: String? = nil,
                        file: StaticString = #file,
                        line: UInt = #line) {
        let source = source ?? Logger.currentModule(filePath: "\(file)")
        let entry = self.find(level: level, message: message, metadata: metadata, source: source)
        XCTAssertNil(entry, "entry was found: \(level), \(source), \(String(describing: metadata)), \(message)",
                     file: file, line: line)
    }
    #endif

    func find(level: Logger.Level, message: String, metadata: Logger.Metadata? = nil, source: String) -> LogEntry? {
        return self.entries.first { entry in
            if entry.level != level {
                return false
            }
            if entry.message != message {
                return false
            }
            if let lhs = entry.metadata, let rhs = metadata {
                if lhs.count != rhs.count {
                    return false
                }

                for lk in lhs.keys {
                    if lhs[lk] != rhs[lk] {
                        return false
                    }
                }

                for rk in rhs.keys {
                    if lhs[rk] != rhs[rk] {
                        return false
                    }
                }

                return true
            }
            if entry.source != source {
                return false
            }

            return true
        }
    }
}

public class MDC {
    private let lock = NSLock()
    private var storage = [Int: Logger.Metadata]()

    public static var global = MDC()

    private init() {}

    public subscript(metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.lock.withLock {
                self.storage[self.threadId]?[metadataKey]
            }
        }
        set {
            self.lock.withLock {
                if self.storage[self.threadId] == nil {
                    self.storage[self.threadId] = Logger.Metadata()
                }
                self.storage[self.threadId]![metadataKey] = newValue
            }
        }
    }

    public var metadata: Logger.Metadata {
        return self.lock.withLock {
            self.storage[self.threadId] ?? [:]
        }
    }

    public func clear() {
        self.lock.withLock {
            _ = self.storage.removeValue(forKey: self.threadId)
        }
    }

    public func with(metadata: Logger.Metadata, _ body: () throws -> Void) rethrows {
        metadata.forEach { self[$0] = $1 }
        defer {
            metadata.keys.forEach { self[$0] = nil }
        }
        try body()
    }

    public func with<T>(metadata: Logger.Metadata, _ body: () throws -> T) rethrows -> T {
        metadata.forEach { self[$0] = $1 }
        defer {
            metadata.keys.forEach { self[$0] = nil }
        }
        return try body()
    }

    // for testing
    internal func flush() {
        self.lock.withLock {
            self.storage.removeAll()
        }
    }

    private var threadId: Int {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        return Int(pthread_mach_thread_np(pthread_self()))
        #elseif os(Windows)
        return Int(GetCurrentThreadId())
        #else
        return Int(pthread_self())
        #endif
    }
}

internal extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}

internal struct TestLibrary {
    private let logger = Logger(label: "TestLibrary")
    private let queue = DispatchQueue(label: "TestLibrary")

    public init() {}

    public func doSomething() {
        self.logger.info("TestLibrary::doSomething")
    }

    public func doSomethingAsync(completion: @escaping () -> Void) {
        // libraries that use global loggers and async, need to make sure they propagate the
        // logging metadata when creating a new thread
        let metadata = MDC.global.metadata
        self.queue.asyncAfter(deadline: .now() + 0.1) {
            MDC.global.with(metadata: metadata) {
                self.logger.info("TestLibrary::doSomethingAsync")
                completion()
            }
        }
    }
}

// Sendable

#if compiler(>=5.6)
extension TestLogHandler: @unchecked Sendable {}
extension Recorder: @unchecked Sendable {}
extension Config: @unchecked Sendable {}
extension MDC: @unchecked Sendable {}
#endif
