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
    // swift-log provides compile-time traits to set a maximum log level, eliminating less severe
    // levels from your binary. When a log level is compiled out, both the level-specific method
    // (e.g., `logger.debug()`) and calls to `logger.log(level: .debug)` become no-ops at compile
    // time, with zero runtime overhead.
    //
    // Usage:
    //   .package(url: "...", traits: ["MaxLogLevelError"])
    //
    // Traits are additive - if multiple max level traits are specified, both traits are
    // applied and the effective behavior is the most restrictive one. For example, specifying
    // both MaxLogLevelError and MaxLogLevelWarning applies both traits, but the effective
    // maximum log level will be MaxLogLevelError (the more restrictive one).
    //
    // Performance impact:
    //   - Level-specific methods (`.debug()`, `.info()`, etc.): Entire method body compiled out
    //   - Generic `.log(level:)`: Uses O(1) switch statement; disabled levels jump to no-op default case
    //
    // See Benchmarks/ directory for performance comparisons across different trait configurations.
    traits: [
        // MaxLogLevelTrace: All log levels available (trace, debug, info, notice, warning, error, critical)
        .trait(name: "MaxLogLevelTrace"),

        // MaxLogLevelDebug: Debug and above available (compiles out trace)
        .trait(name: "MaxLogLevelDebug"),

        // MaxLogLevelInfo: Info and above available (compiles out trace, debug)
        .trait(name: "MaxLogLevelInfo"),

        // MaxLogLevelNotice: Notice and above available (compiles out trace, debug, info)
        .trait(name: "MaxLogLevelNotice"),

        // MaxLogLevelWarning: Warning and above available (compiles out trace, debug, info, notice)
        .trait(name: "MaxLogLevelWarning"),

        // MaxLogLevelError: Error and above available (compiles out trace, debug, info, notice, warning)
        .trait(name: "MaxLogLevelError"),

        // MaxLogLevelCritical: Only critical available (compiles out all except critical)
        .trait(name: "MaxLogLevelCritical"),

        // MaxLogLevelNone: All logging compiled out (no log levels available)
        .trait(name: "MaxLogLevelNone"),

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
