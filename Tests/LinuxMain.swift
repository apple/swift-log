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
// LinuxMain.swift
//
import XCTest

///
/// NOTE: This file was generated by generate_linux_tests.rb
///
/// Do NOT edit this file directly as it will be regenerated automatically when needed.
///

#if os(Linux) || os(FreeBSD) || os(Windows) || os(Android)
@testable import LoggingTests
#if swift(>=5.1)
@testable import LoggingTests_51plus
#endif

XCTMain([
    testCase(CompatibilityTest.allTests),
    testCase(GlobalLoggerTest.allTests),
    testCase(LocalLoggerTest.allTests),
    testCase(LoggingTest.allTests),
    testCase(MDCTest.allTests),
    testCase(MetadataProviderTest.allTests),
])
#endif
