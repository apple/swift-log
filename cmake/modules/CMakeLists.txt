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

set(SwiftLog_EXPORTS_FILE ${CMAKE_CURRENT_BINARY_DIR}/SwiftLogExports.cmake)

configure_file(SwiftLogConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/SwiftLogConfig.cmake)

get_property(SwiftLog_EXPORTS GLOBAL PROPERTY SwiftLog_EXPORTS)
export(TARGETS ${SwiftLog_EXPORTS}
  FILE ${SwiftLog_EXPORTS_FILE})
