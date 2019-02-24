// swift-tools-version:4.2
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
    name: "logging",
    products: [
        .library(name: "Logging", targets: ["Logging"]),
    ],
    targets: [
        .target(
            name: "Logging",
            dependencies: []
        ),
        .target(
            name: "ExampleImplementation",
            dependencies: ["Logging"]
        ),
        .target(
            name: "ExampleUsage",
            dependencies: ["Logging", "ExampleImplementation"]
        ),
        .testTarget(
            name: "LoggingTests",
            dependencies: ["Logging"]
        ),
    ]
)
