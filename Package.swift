// swift-tools-version:6.1
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
    // MARK: - Package Traits
    //
    // swift-log provides compile-time traits to completely eliminate specific log levels from your binary.
    // When a log level is disabled via a trait, both the level-specific method (e.g., `logger.debug()`)
    // and calls to `logger.log(level: .debug)` become no-ops at compile time, with zero runtime overhead.
    //
    // Usage:
    //   .package(url: "...", traits: ["DisableDebugLogs"])
    //
    // Performance impact:
    //   - Level-specific methods (`.debug()`, `.info()`, etc.): Entire method body compiled out
    //   - Generic `.log(level:)`: Uses O(1) switch statement; disabled levels jump to no-op default case
    traits: [
        // DisableTraceLogs: Compile out all `.trace()` and `.log(level: .trace)` calls
        .trait(name: "DisableTraceLogs"),

        // DisableDebugLogs: Compile out all `.debug()` and `.log(level: .debug)` calls
        .trait(name: "DisableDebugLogs"),

        // DisableInfoLogs: Compile out all `.info()` and `.log(level: .info)` calls
        .trait(name: "DisableInfoLogs"),

        // DisableNoticeLogs: Compile out all `.notice()` and `.log(level: .notice)` calls
        .trait(name: "DisableNoticeLogs"),

        // DisableWarningLogs: Compile out all `.warning()` and `.log(level: .warning)` calls
        .trait(name: "DisableWarningLogs"),

        // DisableErrorLogs: Compile out all `.error()` and `.log(level: .error)` calls
        .trait(name: "DisableErrorLogs"),

        // DisableCriticalLogs: Compile out all `.critical()` and `.log(level: .critical)` calls
        .trait(name: "DisableCriticalLogs"),

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

for target in package.targets {
    var settings = target.swiftSettings ?? []
    settings.append(.enableExperimentalFeature("StrictConcurrency=complete"))
    target.swiftSettings = settings
}

// ---    STANDARD CROSS-REPO SETTINGS DO NOT EDIT   --- //
for target in package.targets {
    switch target.type {
    case .regular, .test, .executable:
        var settings = target.swiftSettings ?? []
        // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
        settings.append(.enableUpcomingFeature("MemberImportVisibility"))
        target.swiftSettings = settings
    case .macro, .plugin, .system, .binary:
        ()  // not applicable
    @unknown default:
        ()  // we don't know what to do here, do nothing
    }
}
// --- END: STANDARD CROSS-REPO SETTINGS DO NOT EDIT --- //
