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

cmake_minimum_required(VERSION 3.19)

# Initialize C language first to inspect the compiler environment
project(swift-log LANGUAGES C)

# Set Swift compiler target from C compiler target if not manually set for Windows
if(WIN32 AND NOT CMAKE_Swift_COMPILER_TARGET)
    if(CMAKE_C_COMPILER_ARCHITECTURE_ID MATCHES "(ARM64|arm64|aarch64)")
        set(CMAKE_Swift_COMPILER_TARGET "aarch64-unknown-windows-msvc" CACHE STRING "Swift compiler target triple")
    elseif(CMAKE_C_COMPILER_ARCHITECTURE_ID MATCHES "(X86|x64|AMD64|x86_64)")
        set(CMAKE_Swift_COMPILER_TARGET "x86_64-unknown-windows-msvc" CACHE STRING "Swift compiler target triple")
    endif()
endif()

# Enable Swift after C defines the architecture
enable_language(Swift)

option(BUILD_SHARED_LIBS "Build shared libraries by default" YES)

set(CMAKE_Swift_LANGUAGE_VERSION 6)

if(CMAKE_Swift_COMPILER_VERSION VERSION_LESS "6.1")
  message(FATAL_ERROR "swift-log requires Swift compiler version 6.1 or newer. Detected version: ${CMAKE_Swift_COMPILER_VERSION}")
endif()

set(SWIFT_LOG_COMMON_COMPILE_OPTIONS
  "SHELL:-enable-upcoming-feature ExistentialAny"
  "SHELL:-enable-upcoming-feature MemberImportVisibility"
  "SHELL:-enable-upcoming-feature InternalImportsByDefault"
  "SHELL:-enable-upcoming-feature NonisolatedNonsendingByDefault"
  "SHELL:-Xfrontend -require-explicit-sendable"
  "SHELL:-package-name swift_log")

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)

if(MSVC)
  message(STATUS "MSVC condition triggered successfully!")
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
  set(CMAKE_Swift_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
endif()

include(GNUInstallDirs)
include(SwiftSupport)

if(NOT APPLE)
  find_package(dispatch QUIET)
  find_package(Foundation QUIET)
endif()

add_subdirectory(Sources)

add_subdirectory(cmake/modules)
