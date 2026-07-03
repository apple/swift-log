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

import Testing
@testable import Logging

// A simple in-memory stream for capturing log output in tests.
private final class CapturingStream: TextOutputStream, @unchecked Sendable {
      private(set) var output = ""
      func write(_ string: String) { output += string }
}

@Suite("StreamLogHandler timestamp tests")
struct StreamLogHandlerTimestampTests {
      // Helper: emit one log line and return the timestamp field (the first space-delimited token).
      private func captureTimestamp() -> String {
                let stream = CapturingStream()
                let handler = StreamLogHandler(label: "ts-test", stream: stream)
                var logger = Logger(label: "ts-test", factory: { _ in handler })
                logger.logLevel = .info
                logger.info("probe")
                let firstLine = stream.output.components(separatedBy: "\n").first ?? ""
                return firstLine.components(separatedBy: " ").first ?? ""
      }

      @Test("Timestamp includes a millisecond component")
      func timestampContainsMilliseconds() {
                let ts = captureTimestamp()
                #expect(!ts.isEmpty, "log output should not be empty")
                #expect(ts.contains("."), "timestamp '\(ts)' should include a millisecond separator")
      }

      @Test("Millisecond component is exactly 3 digits")
      func timestampMillisecondsAreThreeDigits() {
                let ts = captureTimestamp()
                guard let dotIdx = ts.firstIndex(of: ".") else {
                              Issue.record("no '.' found in timestamp '\(ts)'")
                              return
                }
                let msDigits = ts[ts.index(after: dotIdx)...].prefix(3)
                #expect(
                              msDigits.count == 3 && msDigits.allSatisfy { $0.isNumber },
                              "expected 3-digit millisecond field in '\(ts)', got '\(msDigits)'"
                )
      }

      @Test("Millisecond value is in valid range [0, 999]")
      func timestampMillisecondsAreInRange() {
                let ts = captureTimestamp()
                guard let dotIdx = ts.firstIndex(of: ".") else {
                              Issue.record("no '.' found in timestamp '\(ts)'")
                              return
                }
                let msString = String(ts[ts.index(after: dotIdx)...].prefix(3))
                guard let ms = Int(msString) else {
                              Issue.record("could not parse milliseconds from '\(ts)'")
                              return
                }
                #expect(ms >= 0 && ms <= 999, "milliseconds \(ms) are out of range [0, 999]")
      }

      @Test("Multiple log calls each produce a correctly formatted timestamp")
      func multipleTimestampsAreAllWellFormed() {
                let stream = CapturingStream()
                let handler = StreamLogHandler(label: "ts-test", stream: stream)
                var logger = Logger(label: "ts-test", factory: { _ in handler })
                logger.logLevel = .info
                logger.info("first")
                logger.info("second")
                logger.info("third")

                let lines = stream.output.components(separatedBy: "\n").filter { !$0.isEmpty }
                #expect(lines.count == 3, "expected exactly 3 log lines")

                for line in lines {
                              let ts = line.components(separatedBy: " ").first ?? ""
                              #expect(ts.contains("."), "timestamp '\(ts)' should have a millisecond separator")
                              if let dotIdx = ts.firstIndex(of: ".") {
                                                let msDigits = ts[ts.index(after: dotIdx)...].prefix(3)
                                                #expect(
                                                                      msDigits.count == 3 && msDigits.allSatisfy { $0.isNumber },
                                                                      "timestamp '\(ts)' has malformed milliseconds"
                                                )
                              }
                }
      }

      @Test("Timestamp has expected ISO 8601 structure")
      func timestampStructureMatchesISO8601() {
                let ts = captureTimestamp()
                let tParts = ts.components(separatedBy: "T")
                #expect(tParts.count == 2, "timestamp '\(ts)' should contain exactly one 'T' separator")
                if tParts.count == 2 {
                              let datePart = tParts[0]
                              let timePart = tParts[1]
                              let dateSections = datePart.components(separatedBy: "-")
                              #expect(dateSections.count == 3, "date '\(datePart)' should have 3 dash-separated sections")
                              #expect(timePart.contains(":"), "time '\(timePart)' should contain colons")
                              #expect(timePart.contains("."), "time '\(timePart)' should contain a millisecond dot")
                }
      }
}
