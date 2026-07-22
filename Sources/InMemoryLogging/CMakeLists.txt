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

add_library(InMemoryLogging
  "InMemoryLogHandler.swift"
)

set_target_properties(InMemoryLogging PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES "$<BUILD_INTERFACE:$<TARGET_PROPERTY:Swift_MODULE_DIRECTORY>>;$<BUILD_INTERFACE:$<TARGET_FILE_DIR:InMemoryLogging>>")

target_compile_options(InMemoryLogging PRIVATE
  ${SWIFT_LOG_COMMON_COMPILE_OPTIONS})

target_link_libraries(InMemoryLogging PRIVATE Logging)

_install_target(InMemoryLogging)
set_property(GLOBAL APPEND PROPERTY SwiftLog_EXPORTS InMemoryLogging)
