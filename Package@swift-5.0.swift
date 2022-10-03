// swift-tools-version:5.0
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
        .package(url: "https://github.com/slashmo/swift-distributed-tracing-baggage", .branch("support/swift-5.0")),
    ],
    targets: [
        .target(
            name: "Logging",
            dependencies: [
                .product(name: "InstrumentationBaggage", package: "swift-distributed-tracing-baggage"),
            ]
        ),
        .testTarget(
            name: "LoggingTests",
            dependencies: ["Logging"]
        ),
    ]
)
