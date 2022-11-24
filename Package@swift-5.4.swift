// swift-tools-version:5.4
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

import PackageDescription

let package = Package(
    name: "swift-log",
    products: [
        .library(name: "Logging", targets: ["Logging"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Logging",
            dependencies: [
            ]
        ),
        .testTarget(
            name: "LoggingTests",
            dependencies: ["Logging"]
        ),
        // Due to a compiler bug in parsing/lexing in 5.0,
        // it is not possible to #if out uses of task-local values out of Swift 5.0 code.
        // Thus, tests making use of task-local values must be in their own module.
        .testTarget(
            name: "LoggingTests-51plus",
            dependencies: [
                "Logging",
                "LoggingTests",
            ],
            path: "Tests/LoggingTests_51plus"
        ),
    ]
)
