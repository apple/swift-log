// swift-tools-version:5.8
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

let swiftSettings: [SwiftSetting] = [
    // TODO: re-enable this when 5.8 is no longer supported. Having this
    // enabled propagates to consumers before 5.8 which can result in build
    // failures if the caller is using an existential from this package without.
    // the explicit 'any'.
    //
    // .enableUpcomingFeature("ExistentialAny"),
]

let package = Package(
    name: "swift-log",
    products: [
        .library(name: "Logging", targets: ["Logging"]),
    ],
    targets: [
        .target(
            name: "Logging",
            dependencies: [],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "LoggingTests",
            dependencies: ["Logging"],
            swiftSettings: swiftSettings
        ),
    ]
)
