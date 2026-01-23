// swift-tools-version:6.0
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
        .library(name: "InMemoryLogging", targets: ["InMemoryLogging"]),
    ],
    targets: [
        .target(
            name: "Logging",
            dependencies: []
        ),
        .target(
            name: "InMemoryLogging",
            dependencies: ["Logging"]
        ),
        .testTarget(
            name: "LoggingTests",
            dependencies: ["Logging"]
        ),
        .testTarget(
            name: "InMemoryLoggingTests",
            dependencies: ["InMemoryLogging", "Logging"]
        ),
    ]
)

for target in package.targets
where [.executable, .test, .regular].contains(
    target.type
) {
    var settings = target.swiftSettings ?? []

    // https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md
    // Require `any` for existential types.
    settings.append(.enableUpcomingFeature("ExistentialAny"))

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
    settings.append(.enableUpcomingFeature("MemberImportVisibility"))

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md
    settings.append(.enableUpcomingFeature("InternalImportsByDefault"))

    // https://docs.swift.org/compiler/documentation/diagnostics/nonisolated-nonsending-by-default/
    settings.append(.enableUpcomingFeature("NonisolatedNonsendingByDefault"))

    target.swiftSettings = settings
}
