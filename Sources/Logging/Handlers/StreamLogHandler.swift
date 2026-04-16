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

#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import CRT
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Android)
@preconcurrency import Android
#elseif canImport(Musl)
import Musl
#elseif canImport(WASILibc)
import WASILibc
#else
#error("Unsupported runtime")
#endif

/// Stream log handler presents log messages to STDERR or STDOUT.
///
/// This is a simple implementation of `LogHandler` that directs
/// `Logger` output to either `stderr` or `stdout` via the factory methods.
///
/// Metadata is merged in the following order:
/// 1. Metadata set on the log handler itself is used as the base metadata.
/// 2. The handler's ``metadataProvider`` is invoked, overriding any existing keys.
/// 3. The per-log-statement metadata is merged, overriding any previously set keys.
public struct StreamLogHandler: LogHandler {
    internal typealias _SendableTextOutputStream = TextOutputStream & Sendable

    /// Creates a stream log handler that directs its output to STDOUT.
    public static func standardOutput(label: String) -> StreamLogHandler {
        StreamLogHandler(
            label: label,
            stream: StdioOutputStream.stdout,
            metadataProvider: LoggingSystem.metadataProvider
        )
    }

    /// Creates a stream log handler that directs its output to STDOUT using the metadata provider you provide.
    public static func standardOutput(label: String, metadataProvider: Logger.MetadataProvider?) -> StreamLogHandler {
        StreamLogHandler(label: label, stream: StdioOutputStream.stdout, metadataProvider: metadataProvider)
    }

    /// Creates a stream log handler that directs its output to STDERR.
    public static func standardError(label: String) -> StreamLogHandler {
        StreamLogHandler(
            label: label,
            stream: StdioOutputStream.stderr,
            metadataProvider: LoggingSystem.metadataProvider
        )
    }

    /// Creates a stream log handler that directs its output to STDERR using the metadata provider you provide.
    public static func standardError(label: String, metadataProvider: Logger.MetadataProvider?) -> StreamLogHandler {
        StreamLogHandler(label: label, stream: StdioOutputStream.stderr, metadataProvider: metadataProvider)
    }

    private let stream: any _SendableTextOutputStream
    private let label: String

    /// Get the log level configured for this `Logger`.
    ///
    /// > Note: Changing the log level threshold for a logger only affects the instance of the `Logger` where you change it.
    /// > It is acceptable for logging backends to have some form of global log level override
    /// > that affects multiple or even all loggers. This means a change in `logLevel` to one `Logger` might in
    /// > certain cases have no effect.
    public var logLevel: Logger.Level = .info

    /// The metadata provider.
    public var metadataProvider: Logger.MetadataProvider?

    private var prettyMetadata: String?
    /// Get or set the entire metadata storage as a dictionary.
    public var metadata = Logger.Metadata() {
        didSet {
            self.prettyMetadata = self.prettify(self.metadata)
        }
    }

    /// Add, change, or remove a logging metadata item.
    ///
    /// > Note: Changing the logging metadata only affects the instance of the `Logger` where you change it.
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            self.metadata[metadataKey]
        }
        set {
            self.metadata[metadataKey] = newValue
        }
    }

    // internal for testing only
    internal init(label: String, stream: any _SendableTextOutputStream) {
        self.init(label: label, stream: stream, metadataProvider: LoggingSystem.metadataProvider)
    }

    // internal for testing only
    internal init(label: String, stream: any _SendableTextOutputStream, metadataProvider: Logger.MetadataProvider?) {
        self.label = label
        self.stream = stream
        self.metadataProvider = metadataProvider
    }

    /// Log a message using the log level and source that you provide.
    ///
    /// - parameters:
    ///    - event: The log event containing the level, message, metadata, and source location.
    public func log(event: LogEvent) {
        let effectiveMetadata = StreamLogHandler.prepareMetadata(
            base: self.metadata,
            provider: self.metadataProvider,
            explicit: event.metadata,
            error: event.error,
        )

        let prettyMetadata: String?
        if let effectiveMetadata = effectiveMetadata {
            prettyMetadata = self.prettify(effectiveMetadata)
        } else {
            prettyMetadata = self.prettyMetadata
        }

        var stream = self.stream
        stream.write(
            "\(self.timestamp()) \(event.level)\(self.label.isEmpty ? "" : " ")\(self.label):\(prettyMetadata.map { " \($0)" } ?? "") [\(event.source)] \(event.message)\n"
        )
    }

    @available(*, deprecated, renamed: "log(event:)")
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        self.log(
            event: LogEvent(
                level: level,
                message: message,
                metadata: metadata,
                source: source,
                file: file,
                function: function,
                line: line
            )
        )
    }

    internal static func prepareMetadata(
        base: Logger.Metadata,
        provider: Logger.MetadataProvider?,
        explicit: Logger.Metadata?,
        error: (any Error)?,
    ) -> Logger.Metadata? {
        var metadata = base

        let provided = provider?.get() ?? [:]

        guard !provided.isEmpty || !((explicit ?? [:]).isEmpty) || error != nil else {
            // all per-log-statement values are empty
            return nil
        }

        if !provided.isEmpty {
            metadata.merge(provided, uniquingKeysWith: { _, provided in provided })
        }

        if let explicit = explicit, !explicit.isEmpty {
            metadata.merge(explicit, uniquingKeysWith: { _, explicit in explicit })
        }

        if let error {
            metadata["error.message"] = "\(error)"
            metadata["error.type"] = "\(String(reflecting: type(of: error)))"
        }

        return metadata
    }

    private func prettify(_ metadata: Logger.Metadata) -> String? {
        if metadata.isEmpty {
            return nil
        } else {
            return metadata.lazy.sorted(by: { $0.key < $1.key }).map { "\($0)=\($1)" }.joined(separator: " ")
        }
    }

    private func timestamp() -> String {
        var buffer = [Int8](repeating: 0, count: 255)
        #if os(Windows)
        var timestamp = __time64_t()
        _ = _time64(&timestamp)

        var localTime = tm()
        _ = _localtime64_s(&localTime, &timestamp)

        _ = strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", &localTime)
        #else
        var timestamp = time(nil)
        guard let localTime = localtime(&timestamp) else {
            return "<unknown>"
        }
        strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", localTime)
        #endif
        return buffer.withUnsafeBufferPointer {
            $0.withMemoryRebound(to: CChar.self) {
                String(cString: $0.baseAddress!)
            }
        }
    }
}

/// A wrapper to facilitate `print`-ing to stderr and stdio that
/// ensures access to the underlying `FILE` is locked to prevent
/// cross-thread interleaving of output.
internal struct StdioOutputStream: TextOutputStream, @unchecked Sendable {
    internal let flushMode: FlushMode
    private let _writeBytes: (UnsafeBufferPointer<UInt8>) -> Void
    private let _flush: () -> Void

    // Using a generic initializer lets Swift infer the concrete file-pointer type
    // at each call site from the values passed. This avoids a CFilePointer typealias
    // that cannot vary by Android API level (API 23 exposes FILE as
    // UnsafeMutablePointer<FILE>; API 24+ makes it OpaquePointer).
    internal init<F>(
        file: F,
        flushMode: FlushMode,
        lock: ((F) -> Void)?,
        unlock: ((F) -> Void)?,
        write: @escaping (UnsafeRawPointer, Int, Int, F) -> Int,
        flush: @escaping (F) -> Int32
    ) {
        self.flushMode = flushMode
        self._writeBytes = { bytes in
            lock?(file)
            defer { unlock?(file) }
            if let base = bytes.baseAddress, bytes.count > 0 {
                _ = write(base, 1, bytes.count, file)
            }
        }
        self._flush = { _ = flush(file) }
    }

    internal func write(_ string: String) {
        self.contiguousUTF8(string).withContiguousStorageIfAvailable { utf8Bytes in
            self._writeBytes(utf8Bytes)
            if case .always = self.flushMode {
                self.flush()
            }
        }!
    }

    /// Flush the underlying stream.
    internal func flush() {
        self._flush()
    }

    internal func contiguousUTF8(_ string: String) -> String.UTF8View {
        var contiguousString = string
        contiguousString.makeContiguousUTF8()
        return contiguousString.utf8
    }

    internal static let stderr: StdioOutputStream = {
        #if canImport(Darwin)
        return StdioOutputStream(
            file: Darwin.stderr,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #elseif os(Windows)
        return StdioOutputStream(
            file: CRT.stderr,
            flushMode: .always,
            lock: _lock_file,
            unlock: _unlock_file,
            write: fwrite,
            flush: fflush
        )
        #elseif canImport(Glibc)
        #if os(FreeBSD) || os(OpenBSD)
        return StdioOutputStream(
            file: Glibc.stderr,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #else
        return StdioOutputStream(
            file: Glibc.stderr!,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #endif
        #elseif canImport(Android)
        return StdioOutputStream(
            file: Android.stderr,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #elseif canImport(Musl)
        return StdioOutputStream(
            file: Musl.stderr!,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #elseif canImport(WASILibc)
        // no file locking on WASI
        return StdioOutputStream(
            file: WASILibc.stderr!,
            flushMode: .always,
            lock: nil,
            unlock: nil,
            write: fwrite,
            flush: fflush
        )
        #else
        #error("Unsupported runtime")
        #endif
    }()

    internal static let stdout: StdioOutputStream = {
        #if canImport(Darwin)
        return StdioOutputStream(
            file: Darwin.stdout,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #elseif os(Windows)
        return StdioOutputStream(
            file: CRT.stdout,
            flushMode: .always,
            lock: _lock_file,
            unlock: _unlock_file,
            write: fwrite,
            flush: fflush
        )
        #elseif canImport(Glibc)
        #if os(FreeBSD) || os(OpenBSD)
        return StdioOutputStream(
            file: Glibc.stdout,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #else
        return StdioOutputStream(
            file: Glibc.stdout!,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #endif
        #elseif canImport(Android)
        return StdioOutputStream(
            file: Android.stdout,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #elseif canImport(Musl)
        return StdioOutputStream(
            file: Musl.stdout!,
            flushMode: .always,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #elseif canImport(WASILibc)
        // no file locking on WASI
        return StdioOutputStream(
            file: WASILibc.stdout!,
            flushMode: .always,
            lock: nil,
            unlock: nil,
            write: fwrite,
            flush: fflush
        )
        #else
        #error("Unsupported runtime")
        #endif
    }()

    /// Defines the flushing strategy for the underlying stream.
    internal enum FlushMode {
        case undefined
        case always
    }
}
