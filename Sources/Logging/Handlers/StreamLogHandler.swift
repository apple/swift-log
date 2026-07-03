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

        private let stream: any TextOutputStream & Sendable
        private let label: String

        public var logLevel: Logger.Level = .info

        public var metadataProvider: Logger.MetadataProvider?

        private var prettyMetadata: String?
        public var metadata = Logger.Metadata() {
                    didSet {
                                    self.prettyMetadata = self.prettify(self.metadata)
                    }
        }

        public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
                    get {
                                    self.metadata[metadataKey]
                    }
                    set {
                                    self.metadata[metadataKey] = newValue
                    }
        }

        public init(label: String, stream: any TextOutputStream & Sendable) {
                    self.init(label: label, stream: stream, metadataProvider: LoggingSystem.metadataProvider)
        }

        public init(label: String, stream: any TextOutputStream & Sendable, metadataProvider: Logger.MetadataProvider?) {
                    self.label = label
                    self.stream = stream
                    self.metadataProvider = metadataProvider
        }

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
                    var tzBuffer = [Int8](repeating: 0, count: 16)
                    let ms: Int
                    #if os(Windows)
                    // Use _ftime64_s for millisecond-precision wall-clock time on Windows.
                    var tb = __timeb64()
                    _ = _ftime64_s(&tb)
                    var localTime = tm()
                    _ = _localtime64_s(&localTime, &tb.time)
                    _ = strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S", &localTime)
                    _ = strftime(&tzBuffer, tzBuffer.count, "%z", &localTime)
                    ms = Int(tb.millitm)
                    #else
                    // Use clock_gettime for sub-second precision (milliseconds).
                    var ts = timespec()
                    clock_gettime(CLOCK_REALTIME, &ts)
                    guard let localTime = localtime(&ts.tv_sec) else {
                                    return "<unknown>"
                    }
                    // Format date+time and timezone separately so we can inject milliseconds.
                    strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S", localTime)
                    strftime(&tzBuffer, tzBuffer.count, "%z", localTime)
                    ms = Int(ts.tv_nsec) / 1_000_000
                    #endif
                    let dateStr = buffer.withUnsafeBufferPointer {
                                    $0.withMemoryRebound(to: CChar.self) {
                                                        String(cString: $0.baseAddress!)
                                    }
                    }
                    let tzStr = tzBuffer.withUnsafeBufferPointer {
                                    $0.withMemoryRebound(to: CChar.self) {
                                                        String(cString: $0.baseAddress!)
                                    }
                    }
                    // Zero-pad milliseconds to 3 digits without requiring Foundation.
                    let msStr: String
                    if ms < 10 { msStr = "00\(ms)" }
                    else if ms < 100 { msStr = "0\(ms)" }
                    else { msStr = "\(ms)" }
                    return "\(dateStr).\(msStr)\(tzStr)"
        }
}

/// A wrapper to facilitate `print`-ing to stderr and stdio that
/// ensures access to the underlying `FILE` is locked to prevent
/// cross-thread interleaving of output.
internal struct StdioOutputStream: TextOutputStream, @unchecked Sendable {
        internal let flushMode: FlushMode
        private let _writeBytes: (UnsafeBufferPointer<UInt8>) -> Void
        private let _flush: () -> Void

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

        internal enum FlushMode {
                    case undefined
                    case always
        }
}
