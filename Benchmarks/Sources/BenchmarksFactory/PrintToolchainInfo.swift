//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation

/// Print the resolved `swift` binary path and its `--version` output to stderr.
///
/// Intended for CI exploration: package-benchmark's runner streams stderr to the
/// job log, so calling this from inside a `benchmarks` closure surfaces the
/// toolchain that's executing the benchmark binary.
public func printSwiftToolchainInfo() {
    var lines: [String] = ["===== Swift toolchain info ====="]

    #if swift(>=6.2)
    lines.append("Compile-time Swift: >=6.2")
    #elseif swift(>=6.1)
    lines.append("Compile-time Swift: >=6.1, <6.2")
    #elseif swift(>=6.0)
    lines.append("Compile-time Swift: >=6.0, <6.1")
    #else
    lines.append("Compile-time Swift: <6.0")
    #endif

    if let path = ProcessInfo.processInfo.environment["PATH"] {
        lines.append("PATH: \(path)")
    }

    if let output = runShell("/usr/bin/env", ["which", "-a", "swift"]) {
        lines.append("which -a swift:\n\(output)")
    }

    #if os(macOS)
    if let output = runShell("/usr/bin/xcrun", ["-f", "swift"]) {
        lines.append("xcrun -f swift: \(output)")
    }
    if let output = runShell("/usr/bin/xcrun", ["--version"]) {
        lines.append("xcrun --version: \(output)")
    }
    #endif

    if let output = runShell("/usr/bin/env", ["swift", "--version"]) {
        lines.append("swift --version:\n\(output)")
    }

    lines.append("================================")

    let blob = lines.joined(separator: "\n") + "\n"
    FileHandle.standardError.write(Data(blob.utf8))
}

private func runShell(_ launchPath: String, _ arguments: [String]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
        return "<failed to run \(launchPath) \(arguments.joined(separator: " ")): \(error)>"
    }
}
