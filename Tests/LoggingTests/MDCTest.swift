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
import Testing

@testable import Logging

struct MDCTest {
    @Test func test() throws {
        // run the program
        MDC.global["foo"] = "bar"
        let group = DispatchGroup()
        for r in 5...10 {
            group.enter()
            DispatchQueue(label: "mdc-test-queue-\(r)").async {
                let add = Int.random(in: 10...1000)
                let remove = Int.random(in: 0...add - 1)
                for i in 0...add {
                    MDC.global["key-\(i)"] = "value-\(i)"
                }
                for i in 0...remove {
                    MDC.global["key-\(i)"] = nil
                }
                #expect((add - remove) == MDC.global.metadata.count, "expected number of entries to match")
                for i in remove + 1...add {
                    #expect(MDC.global["key-\(i)"] != nil, "expecting value for key-\(i)")
                }
                for i in 0...remove {
                    #expect(MDC.global["key-\(i)"] == nil, "not expecting value for key-\(i)")
                }
                MDC.global.clear()
                group.leave()
            }
        }
        group.wait()
        #expect(MDC.global["foo"] == "bar", "expecting to find top items")
        MDC.global["foo"] = nil
        #expect(MDC.global.metadata.isEmpty, "MDC should be empty")
    }
}
