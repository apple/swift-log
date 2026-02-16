// swift-tools-version:6.2
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
    traits: [
        .trait(name: "MaxLogLevelDebug", description: "Debug and above available (compiles out trace)"),
        .trait(name: "MaxLogLevelInfo", description: "Info and above available (compiles out trace, debug)"),
        .trait(name: "MaxLogLevelNotice", description: "Notice and above available (compiles out trace, debug, info)"),
        .trait(
            name: "MaxLogLevelWarning",
            description: "Warning and above available (compiles out trace, debug, info, notice)"
        ),
        .trait(
            name: "MaxLogLevelError",
            description: "Error and above available (compiles out trace, debug, info, notice, warning)"
        ),
        .trait(name: "MaxLogLevelCritical", description: "Only critical available (compiles out all except critical)"),
        .trait(name: "MaxLogLevelNone", description: "All logging compiled out (no log levels available)"),

        // By default, no traits are enabled (all log levels available)
        .default(enabledTraits: []),
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

    // Ensure all public types are explicitly annotated as Sendable or not Sendable.
    settings.append(.unsafeFlags(["-Xfrontend", "-require-explicit-sendable"]))

    target.swiftSettings = settings
}
