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
import Dispatch
@testable import Logging
import XCTest

class MDCTest: XCTestCase {
    func test1() throws {
        // bootstrap with our test logger
        let logging = TestLogging()
        LoggingSystem.bootstrapInternal(logging.make)

        // run the program
        MDC.global["foo"] = "bar"
        let group = DispatchGroup()
        for r in 5 ... 10 {
            group.enter()
            DispatchQueue(label: "mdc-test-queue-\(r)").async {
                let add = Int.random(in: 10 ... 1000)
                let remove = Int.random(in: 0 ... add - 1)
                for i in 0 ... add {
                    MDC.global["key-\(i)"] = "value-\(i)"
                }
                for i in 0 ... remove {
                    MDC.global["key-\(i)"] = nil
                }
                XCTAssertEqual(add - remove, MDC.global.metadata.count, "expected number of entries to match")
                for i in remove + 1 ... add {
                    XCTAssertNotNil(MDC.global["key-\(i)"], "expecting value for key-\(i)")
                }
                for i in 0 ... remove {
                    XCTAssertNil(MDC.global["key-\(i)"], "not expecting value for key-\(i)")
                }
                MDC.global.clear()
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(MDC.global["foo"], "bar", "expecting to find top items")
        MDC.global["foo"] = nil
        XCTAssertTrue(MDC.global.metadata.isEmpty, "MDC should be empty")
    }
}
