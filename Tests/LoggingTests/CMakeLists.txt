#===----------------------------------------------------------------------===#
#
# This source file is part of the Swift Logging API open source project
#
# Copyright (c) 2018-2026 Apple Inc. and the Swift Logging API project authors
# Licensed under Apache License v2.0
#
# See LICENSE.txt for license information
# See CONTRIBUTORS.txt for the list of Swift Logging API project authors
#
# SPDX-License-Identifier: Apache-2.0
#
#===----------------------------------------------------------------------===#

add_library(LoggingTests
  CompatibilityTest.swift
  GlobalLoggingTest.swift
  LocalLoggingTest.swift
  LockTest.swift
  LogEventTest.swift
  LoggingTest.swift
  MDCTest.swift
  MetadataAttributesTest.swift
  MetadataProviderTest.swift
  MetadataValueInterpolationTest.swift
  StreamLogHandlerTest.swift
  SwiftLogNoOpLogHandlerTest.swift
  TaskLocalLoggerTest.swift
  TestLogger.swift
  TestSendable.swift
  SubDirectoryOfLoggingTests/EmitALogFromSubDirectory.swift)

target_compile_options(LoggingTests PRIVATE
  ${SWIFT_LOG_COMMON_COMPILE_OPTIONS})

if(APPLE)
  target_compile_options(LoggingTests PRIVATE
    "SHELL:-plugin-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing")
endif()

if(APPLE)
  find_library(TESTING_FRAMEWORK Testing
    PATHS "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks"
          "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"
    NO_DEFAULT_PATH)
  target_link_libraries(LoggingTests PRIVATE Logging ${TESTING_FRAMEWORK})
else()
  target_link_libraries(LoggingTests PRIVATE Logging Testing)
endif()
