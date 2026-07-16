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

if(APPLE)
  add_library(InMemoryLoggingTests MODULE
    InMemoryLogHandlerTests.swift)
  set_target_properties(InMemoryLoggingTests PROPERTIES
    BUNDLE TRUE
    BUNDLE_EXTENSION xctest)
else()
  add_executable(InMemoryLoggingTests
    InMemoryLogHandlerTests.swift)
endif()

target_compile_options(InMemoryLoggingTests PRIVATE
  ${SWIFT_LOG_COMMON_COMPILE_OPTIONS})

if(APPLE)
  target_compile_options(InMemoryLoggingTests PRIVATE
    "SHELL:-plugin-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing")
endif()

if(APPLE)
  find_library(TESTING_FRAMEWORK Testing
    PATHS "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"
    NO_DEFAULT_PATH)
  target_link_libraries(InMemoryLoggingTests PRIVATE InMemoryLogging Logging ${TESTING_FRAMEWORK})
else()
  target_link_libraries(InMemoryLoggingTests PRIVATE InMemoryLogging Logging Testing)
endif()

add_test(NAME InMemoryLoggingTests COMMAND InMemoryLoggingTests)
