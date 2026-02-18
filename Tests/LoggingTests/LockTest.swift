//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2018-2026 Apple Inc. and the Swift Logging API project authors
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
// Copyright (c) 2017-2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Testing

@testable import Logging

#if canImport(Dispatch)
import Dispatch
private let canImportDispatch = true
#else
private let canImportDispatch = false
#endif

@Suite("Lock Test Suite")
struct LockTestSuite {
    @Test(.enabled(if: canImportDispatch)) func testLockMutualExclusion() {
        #if canImport(Dispatch)
        let l = Lock()

        nonisolated(unsafe) var x = 1
        let q = DispatchQueue(label: "q")
        let g = DispatchGroup()
        let sem1 = DispatchSemaphore(value: 0)
        let sem2 = DispatchSemaphore(value: 0)

        l.lock()

        q.async(group: g) {
            sem1.signal()
            l.lock()
            x = 2
            l.unlock()
            sem2.signal()
        }

        sem1.wait()
        #expect(DispatchTimeoutResult.timedOut == g.wait(timeout: .now() + 0.1))
        #expect(1 == x)

        l.unlock()
        sem2.wait()

        l.lock()
        #expect(2 == x)
        l.unlock()
        #endif  // canImport(Dispatch)
    }
}
