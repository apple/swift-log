//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Logging
import Testing

@Suite
struct MetadataValueTest {
    @Test
    func descriptionRendering() {
        #expect(Logger.MetadataValue.array([]).description == "[]")
        #expect(Logger.MetadataValue.array(["a", "b"]).description == ["a", "b"].description)

        #expect(Logger.MetadataValue.dictionary([:]).description == "[:]")
        #expect(Logger.MetadataValue.dictionary(["k": "v"]).description == ["k": "v"].description)
        #expect(
            Logger.MetadataValue.dictionary(["outer": ["inner": "leaf"]]).description
                == "[\"outer\": [\"inner\": \"leaf\"]]"
        )
    }

    @Test
    func equatableCompareson() {
        let lhs: Logger.MetadataValue = ["a": ["1", "2"]]
        let rhs: Logger.MetadataValue = ["a": ["1", "2"]]
        let different: Logger.MetadataValue = ["a": ["1", "3"]]

        #expect(lhs == rhs)
        #expect(lhs != different)
    }

    @Test
    func descriptionOfNestedArraysGrowsLinearlyNotExponentially() {
        var value: Logger.MetadataValue = .string("leaf")
        for _ in 0..<100 {
            value = .array([value])
        }
        // "leaf".debugDescription + each level adds a "[" and "]".
        #expect(value.description.count == 6 + 2 * 100)
    }

    @Test
    func equatableComparesNestedArrays() {
        var lhs: Logger.MetadataValue = .string("leaf")
        var rhs: Logger.MetadataValue = .string("leaf")
        for _ in 0..<100 {
            lhs = .array([lhs])
            rhs = .array([rhs])
        }
        #expect(lhs == rhs)
    }
}
