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

//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import ucrt
import WinSDK
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Android)
@preconcurrency import Android
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(Bionic)
@preconcurrency import Bionic
#elseif canImport(WASILibc)
@preconcurrency import WASILibc
#if canImport(wasi_pthread)
import wasi_pthread
#endif
#else
#error("The concurrency lock module was unable to identify your C library.")
#endif

/// A threading lock based on `libpthread` instead of `libdispatch`.
///
/// This object provides a lock on top of a single `pthread_mutex_t`. This kind
/// of lock is safe to use with `libpthread`-based threading models, such as the
/// one used by NIO. On Windows, the lock is based on the substantially similar
/// `SRWLOCK` type.
package final class Lock {
    #if os(Windows)
    fileprivate let mutex: UnsafeMutablePointer<SRWLOCK> =
        UnsafeMutablePointer.allocate(capacity: 1)
    #elseif os(OpenBSD)
    fileprivate let mutex: UnsafeMutablePointer<pthread_mutex_t?> =
        UnsafeMutablePointer.allocate(capacity: 1)
    #else
    fileprivate let mutex: UnsafeMutablePointer<pthread_mutex_t> =
        UnsafeMutablePointer.allocate(capacity: 1)
    #endif

    /// Create a new lock.
    package init() {
        #if os(Windows)
        InitializeSRWLock(self.mutex)
        #elseif os(OpenBSD)
        var attr = pthread_mutexattr_t(bitPattern: 0)
        let err = pthread_mutex_init(self.mutex, &attr)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
        #elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
        var attr = pthread_mutexattr_t()
        pthread_mutexattr_init(&attr)
        debugOnly {
            pthread_mutexattr_settype(&attr, .init(PTHREAD_MUTEX_ERRORCHECK))
        }

        let err = pthread_mutex_init(self.mutex, &attr)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
        #endif
    }

    deinit {
        #if os(Windows)
        // SRWLOCK does not need to be free'd
        #elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
        let err = pthread_mutex_destroy(self.mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
        #endif
        mutex.deallocate()
    }

    /// Acquire the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `unlock`, to simplify lock handling.
    package func lock() {
        #if os(Windows)
        AcquireSRWLockExclusive(self.mutex)
        #elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
        let err = pthread_mutex_lock(self.mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
        #endif
    }

    /// Release the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `lock`, to simplify lock handling.
    package func unlock() {
        #if os(Windows)
        ReleaseSRWLockExclusive(self.mutex)
        #elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
        let err = pthread_mutex_unlock(self.mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
        #endif
    }

    /// Acquire the lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lock` and `unlock` in
    /// most situations, as it ensures that the lock will be released regardless
    /// of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the lock.
    /// - Returns: The value returned by the block.
    @inlinable
    package func withLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return try body()
    }

    // specialise Void return (for performance)
    @inlinable
    package func withLockVoid(_ body: () throws -> Void) rethrows {
        try self.withLock(body)
    }
}

/// A utility function that runs the body code only in debug builds, without
/// emitting compiler warnings.
///
/// This is currently the only way to do this in Swift: see
/// https://forums.swift.org/t/support-debug-only-code/11037 for a discussion.
@inlinable
internal func debugOnly(_ body: () -> Void) {
    assert(
        {
            body()
            return true
        }()
    )
}

extension Lock: @unchecked Sendable {}

/// A reader/writer threading lock based on `libpthread` instead of `libdispatch`.
///
/// This object provides a lock on top of a single `pthread_rwlock_t`. This kind
/// of lock is safe to use with `libpthread`-based threading models, such as the
/// one used by NIO. On Windows, the lock is based on the substantially similar
/// `SRWLOCK` type.
internal final class ReadWriteLock: @unchecked Sendable {
    #if canImport(WASILibc)
    // WASILibc is single threaded, provides no locks
    #elseif os(Windows)
    fileprivate let rwlock: UnsafeMutablePointer<SRWLOCK> =
        UnsafeMutablePointer.allocate(capacity: 1)
    fileprivate var shared: Bool = true
    #else
    fileprivate let rwlock: UnsafeMutablePointer<pthread_rwlock_t> =
        UnsafeMutablePointer.allocate(capacity: 1)
    #endif

    /// Create a new lock.
    public init() {
        #if os(Windows)
        InitializeSRWLock(self.rwlock)
        #elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
        let err = pthread_rwlock_init(self.rwlock, nil)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
        #endif
    }

    deinit {
        #if os(Windows)
        // SRWLOCK does not need to be free'd
        self.rwlock.deallocate()
        #elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
        let err = pthread_rwlock_destroy(self.rwlock)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
        self.rwlock.deallocate()
        #endif
    }

    /// Acquire a reader lock.
    ///
    /// Whenever possible, consider using `withReaderLock` instead of this
    /// method and `unlock`, to simplify lock handling.
    fileprivate func lockRead() {
        #if os(Windows)
        AcquireSRWLockShared(self.rwlock)
        self.shared = true
        #elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
        let err = pthread_rwlock_rdlock(self.rwlock)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
        #endif
    }

    /// Acquire a writer lock.
    ///
    /// Whenever possible, consider using `withWriterLock` instead of this
    /// method and `unlock`, to simplify lock handling.
    fileprivate func lockWrite() {
        #if os(Windows)
        AcquireSRWLockExclusive(self.rwlock)
        self.shared = false
        #elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
        let err = pthread_rwlock_wrlock(self.rwlock)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
        #endif
    }

    /// Release the lock.
    ///
    /// Whenever possible, consider using `withReaderLock` and `withWriterLock`
    /// instead of this method and `lockRead` and `lockWrite`, to simplify lock
    /// handling.
    fileprivate func unlock() {
        #if os(Windows)
        if self.shared {
            ReleaseSRWLockShared(self.rwlock)
        } else {
            ReleaseSRWLockExclusive(self.rwlock)
        }
        #elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
        let err = pthread_rwlock_unlock(self.rwlock)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
        #endif
    }
}

extension ReadWriteLock {
    /// Acquire the reader lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lockRead` and `unlock`
    /// in most situations, as it ensures that the lock will be released
    /// regardless of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the reader lock.
    /// - Returns: The value returned by the block.
    @inlinable
    internal func withReaderLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lockRead()
        defer {
            self.unlock()
        }
        return try body()
    }

    /// Acquire the writer lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lockWrite` and `unlock`
    /// in most situations, as it ensures that the lock will be released
    /// regardless of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the writer lock.
    /// - Returns: The value returned by the block.
    @inlinable
    internal func withWriterLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lockWrite()
        defer {
            self.unlock()
        }
        return try body()
    }

    // specialise Void return (for performance)
    @inlinable
    internal func withReaderLockVoid(_ body: () throws -> Void) rethrows {
        try self.withReaderLock(body)
    }

    // specialise Void return (for performance)
    @inlinable
    internal func withWriterLockVoid(_ body: () throws -> Void) rethrows {
        try self.withWriterLock(body)
    }
}
