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
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    import Darwin
#else
    import Glibc
#endif

/// A threading lock based on `libpthread` instead of `libdispatch`.
///
/// This object provides a lock on top of a single `pthread_mutex_t`. This kind
/// of lock is safe to use with `libpthread`-based threading models, such as the
/// one used by NIO.
internal final class Lock {
    fileprivate let mutex: UnsafeMutablePointer<pthread_mutex_t> = UnsafeMutablePointer.allocate(capacity: 1)

    /// Create a new lock.
    public init() {
        let err = pthread_mutex_init(self.mutex, nil)
        precondition(err == 0)
    }

    deinit {
        let err = pthread_mutex_destroy(self.mutex)
        precondition(err == 0)
        self.mutex.deallocate()
    }

    /// Acquire the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `unlock`, to simplify lock handling.
    public func lock() {
        let err = pthread_mutex_lock(self.mutex)
        precondition(err == 0)
    }

    /// Release the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `lock`, to simplify lock handling.
    public func unlock() {
        let err = pthread_mutex_unlock(self.mutex)
        precondition(err == 0)
    }
}

extension Lock {
    /// Acquire the lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lock` and `unlock` in
    /// most situations, as it ensures that the lock will be released regardless
    /// of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the lock.
    /// - Returns: The value returned by the block.
    @inlinable
    public func withLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return try body()
    }

    // specialise Void return (for performance)
    @inlinable
    public func withLockVoid(_ body: () throws -> Void) rethrows {
        try self.withLock(body)
    }
}

/// A threading lock based on `libpthread` instead of `libdispatch`.
///
/// This object provides a lock on top of a single `pthread_mutex_t`. This kind
/// of lock is safe to use with `libpthread`-based threading models, such as the
/// one used by NIO.
internal final class ReadWriteLock {
    fileprivate let rwlock: UnsafeMutablePointer<pthread_rwlock_t> = UnsafeMutablePointer.allocate(capacity: 1)

    /// Create a new lock.
    public init() {
        let err = pthread_rwlock_init(self.rwlock, nil)
        precondition(err == 0)
    }

    deinit {
        let err = pthread_rwlock_destroy(self.rwlock)
        precondition(err == 0)
        self.rwlock.deallocate()
    }

    /// Acquire a reader lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `unlock`, to simplify lock handling.
    public func lockRead() {
        let err = pthread_rwlock_rdlock(self.rwlock)
        precondition(err == 0)
    }

    /// Acquire a writer lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `unlock`, to simplify lock handling.
    public func lockWrite() {
        let err = pthread_rwlock_wrlock(self.rwlock)
        precondition(err == 0)
    }

    /// Release the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `lock`, to simplify lock handling.
    public func unlock() {
        let err = pthread_rwlock_unlock(self.rwlock)
        precondition(err == 0)
    }
}

extension ReadWriteLock {
    /// Acquire the reader lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lock` and `unlock` in
    /// most situations, as it ensures that the lock will be released regardless
    /// of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the lock.
    /// - Returns: The value returned by the block.
    @inlinable
    public func withReaderLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lockRead()
        defer {
            self.unlock()
        }
        return try body()
    }

    /// Acquire the writer lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lock` and `unlock` in
    /// most situations, as it ensures that the lock will be released regardless
    /// of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the lock.
    /// - Returns: The value returned by the block.
    @inlinable
    public func withWriterLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lockWrite()
        defer {
            self.unlock()
        }
        return try body()
    }

    // specialise Void return (for performance)
    @inlinable
    public func withReaderLockVoid(_ body: () throws -> Void) rethrows {
        try self.withReaderLock(body)
    }

    // specialise Void return (for performance)
    @inlinable
    public func withWriterLockVoid(_ body: () throws -> Void) rethrows {
        try self.withWriterLock(body)
    }
}
