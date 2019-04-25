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
//
// LoggingTest+XCTest.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

extension LoggingTest {
    static var allTests: [(String, (LoggingTest) -> () throws -> Void)] {
        return [
            ("testAutoclosure", testAutoclosure),
            ("testMultiplex", testMultiplex),
            ("testDictionaryMetadata", testDictionaryMetadata),
            ("testListMetadata", testListMetadata),
            ("testStringConvertibleMetadata", testStringConvertibleMetadata),
            ("testAutoClosuresAreNotForcedUnlessNeeded", testAutoClosuresAreNotForcedUnlessNeeded),
            ("testLocalMetadata", testLocalMetadata),
            ("testCustomFactory", testCustomFactory),
            ("testAllLogLevelsExceptCriticalCanBeBlocked", testAllLogLevelsExceptCriticalCanBeBlocked),
            ("testAllLogLevelsWork", testAllLogLevelsWork),
            ("testLogMessageWithStringInterpolation", testLogMessageWithStringInterpolation),
            ("testLoggingAString", testLoggingAString),
            ("testMultiplexerIsValue", testMultiplexerIsValue),
            ("testLoggerWithGlobalOverride", testLoggerWithGlobalOverride),
            ("testLogLevelCases", testLogLevelCases),
            ("testLogLevelOrdering", testLogLevelOrdering),
            ("testStdioLogHandlerOutputsToStderr", testStdioLogHandlerOutputsToStderr),
            ("testStdioLogHandlerDefaultsToStdout", testStdioLogHandlerDefaultsToStdout),
        ]
    }
}
