//
//  StdioOutputStream.swift
//  swift-log
//
//  Created by Samuel Murray on 2026-04-15.
//

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
