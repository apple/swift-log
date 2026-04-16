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
import Testing

@testable import Logging

#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import WinSDK
#elseif canImport(Android)
import Android
#else
import Glibc
#endif

struct StreamLogHandlerTest {
    final class InterceptStream: TextOutputStream {
        var interceptedText: String?
        var strings = [String]()

        func write(_ string: String) {
            // This is a test implementation, a real implementation would include locking
            self.strings.append(string)
            self.interceptedText = (self.interceptedText ?? "") + string
        }
    }

    @Test func streamLogHandlerWritesToAStream() {
        let interceptStream = InterceptStream()
        let log = Logger(
            label: "test",
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)")

        let messageSucceeded = interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines)
            .hasSuffix(testString)

        #expect(messageSucceeded ?? false)
        #expect(interceptStream.strings.count == 1)
    }

    @Test func streamLogHandlerOutputFormat() {
        let interceptStream = InterceptStream()
        let label = "testLabel"
        let source = "testSource"
        let log = Logger(
            label: label,
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)", source: source)

        let pattern =
            "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+|-)\\d{4}\\s\(Logger.Level.critical)\\s\(label):\\s\\[\(source)\\]\\s\(testString)$"

        let messageSucceeded =
            interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines).range(
                of: pattern,
                options: .regularExpression
            ) != nil

        #expect(messageSucceeded)
        #expect(interceptStream.strings.count == 1)
    }

    @Test func streamLogHandlerOutputFormatWithEmptyLabel() {
        let interceptStream = InterceptStream()
        let source = "testSource"
        let log = Logger(
            label: "",
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)", source: source)

        let pattern =
            "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+|-)\\d{4}\\s\(Logger.Level.critical):\\s\\[\(source)\\]\\s\(testString)$"

        let messageSucceeded =
            interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines).range(
                of: pattern,
                options: .regularExpression
            ) != nil

        #expect(messageSucceeded)
        #expect(interceptStream.strings.count == 1)
    }

    @Test func streamLogHandlerOutputFormatWithMetaData() {
        let interceptStream = InterceptStream()
        let label = "testLabel"
        let source = "testSource"
        let log = Logger(
            label: label,
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)", metadata: ["test": "test"], source: source)

        let pattern =
            "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\+|-)\\d{4}\\s\(Logger.Level.critical)\\s\(label):\\stest=test\\s\\[\(source)\\]\\s\(testString)$"

        let messageSucceeded =
            interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines).range(
                of: pattern,
                options: .regularExpression
            ) != nil

        #expect(messageSucceeded)
        #expect(interceptStream.strings.count == 1)
    }

    @Test func streamLogHandlerOutputFormatWithOrderedMetadata() {
        let interceptStream = InterceptStream()
        let log = Logger(
            label: "testLabel",
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)", metadata: ["a": "a0", "b": "b0"])
        log.critical("\(testString)", metadata: ["b": "b1", "a": "a1"])

        #expect(interceptStream.strings.count == 2)
        guard interceptStream.strings.count == 2 else {
            Issue.record("Intercepted \(interceptStream.strings.count) logs, expected 2")
            return
        }

        #expect(interceptStream.strings[0].contains("a=a0 b=b0"), "LINES: \(interceptStream.strings[0])")
        #expect(interceptStream.strings[1].contains("a=a1 b=b1"), "LINES: \(interceptStream.strings[1])")
    }

    @Test func streamLogHandlerWritesIncludeMetadataProviderMetadata() {
        let interceptStream = InterceptStream()
        let log = Logger(
            label: "test",
            factory: {
                StreamLogHandler(label: $0, stream: interceptStream, metadataProvider: .exampleProvider)
            }
        )

        let testString = "my message is better than yours"
        log.critical("\(testString)")

        let messageSucceeded = interceptStream.interceptedText?.trimmingCharacters(in: .whitespacesAndNewlines)
            .hasSuffix(testString)

        #expect(messageSucceeded ?? false)
        #expect(interceptStream.strings.count == 1)
        let message = interceptStream.strings.first!
        #expect(message.contains("example=example-value"), "message must contain metadata, was: \(message)")
    }

    @Test func stdioOutputStreamWrite() {
        self.withWriteReadFDsAndReadBuffer(flushMode: .always) { logStream, readFD, readBuffer in
            let log = Logger(
                label: "test",
                factory: {
                    StreamLogHandler(label: $0, stream: logStream)
                }
            )
            let testString = "hello\u{0} world"
            log.critical("\(testString)")

            #if os(Windows)
            let size = _read(readFD, readBuffer, 256)
            #else
            let size = read(readFD, readBuffer, 256)
            #endif

            let output = String(
                decoding: UnsafeRawBufferPointer(start: UnsafeRawPointer(readBuffer), count: numericCast(size)),
                as: UTF8.self
            )
            let messageSucceeded = output.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(testString)
            #expect(messageSucceeded)
        }
    }

    @Test func stdioOutputStreamFlush() {
        // flush on every statement
        self.withWriteReadFDsAndReadBuffer(flushMode: .always) { logStream, readFD, readBuffer in
            Logger(
                label: "test",
                factory: {
                    StreamLogHandler(label: $0, stream: logStream)
                }
            ).critical("test")

            #if os(Windows)
            let size = _read(readFD, readBuffer, 256)
            #else
            let size = read(readFD, readBuffer, 256)
            #endif
            #expect(size > -1, "expected flush")

            logStream.flush()

            #if os(Windows)
            let size2 = _read(readFD, readBuffer, 256)
            #else
            let size2 = read(readFD, readBuffer, 256)
            #endif
            #expect(size2 == -1, "expected no flush")
        }
        // default flushing
        self.withWriteReadFDsAndReadBuffer(flushMode: .undefined) { logStream, readFD, readBuffer in
            Logger(
                label: "test",
                factory: {
                    StreamLogHandler(label: $0, stream: logStream)
                }
            ).critical("test")

            #if os(Windows)
            let size = _read(readFD, readBuffer, 256)
            #else
            let size = read(readFD, readBuffer, 256)
            #endif
            #expect(size == -1, "expected no flush")

            logStream.flush()

            #if os(Windows)
            let size2 = _read(readFD, readBuffer, 256)
            #else
            let size2 = read(readFD, readBuffer, 256)
            #endif
            #expect(size2 > -1, "expected flush")
        }
    }

    func withWriteReadFDsAndReadBuffer(
        flushMode: StdioOutputStream.FlushMode,
        _ body: (StdioOutputStream, CInt, UnsafeMutablePointer<Int8>) -> Void
    ) {
        var fds: [Int32] = [-1, -1]
        #if os(Windows)
        fds.withUnsafeMutableBufferPointer {
            let err = _pipe($0.baseAddress, 256, _O_BINARY)
            #expect(err == 0, "_pipe failed \(err)")
        }
        guard let writeFD = _fdopen(fds[1], "w") else {
            Issue.record("Failed to open file")
            return
        }
        #else
        fds.withUnsafeMutableBufferPointer { ptr in
            let err = pipe(ptr.baseAddress!)
            #expect(err == 0, "pipe failed \(err)")
        }
        guard let writeFD = fdopen(fds[1], "w") else {
            Issue.record("Failed to open file")
            return
        }
        #endif

        let writeBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        defer {
            writeBuffer.deinitialize(count: 256)
            writeBuffer.deallocate()
        }

        var err = setvbuf(writeFD, writeBuffer, _IOFBF, 256)
        #expect(err == 0, "setvbuf failed \(err)")

        // Create the stream here while writeFD's concrete type is in scope.
        // Type inference in the generic StdioOutputStream init picks the right
        // C functions for whatever FILE representation this platform/API level uses.
        #if os(Windows)
        let stream = StdioOutputStream(
            file: writeFD,
            flushMode: flushMode,
            lock: _lock_file,
            unlock: _unlock_file,
            write: fwrite,
            flush: fflush
        )
        #else
        let stream = StdioOutputStream(
            file: writeFD,
            flushMode: flushMode,
            lock: flockfile,
            unlock: funlockfile,
            write: fwrite,
            flush: fflush
        )
        #endif

        let readFD = fds[0]
        #if os(Windows)
        let hPipe: HANDLE = HANDLE(bitPattern: _get_osfhandle(readFD))!
        #expect(hPipe != INVALID_HANDLE_VALUE)

        var dwMode: DWORD = DWORD(PIPE_NOWAIT)
        let bSucceeded = SetNamedPipeHandleState(hPipe, &dwMode, nil, nil)
        #expect(bSucceeded)
        #else
        err = fcntl(readFD, F_SETFL, fcntl(readFD, F_GETFL) | O_NONBLOCK)
        #expect(err == 0, "fcntl failed \(err)")
        #endif

        let readBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: 256)
        defer {
            readBuffer.deinitialize(count: 256)
            readBuffer.deallocate()
        }

        // the actual test
        body(stream, readFD, readBuffer)

        for fd in fds {
            #if os(Windows)
            _close(fd)
            #else
            close(fd)
            #endif
        }
    }
}

// MARK: - Sendable

// used to test logging stream which requires Sendable conformance
// @unchecked Sendable since manages it own state
extension StreamLogHandlerTest.InterceptStream: @unchecked Sendable {}
