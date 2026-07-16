
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

# Returns the os name in a variable
#
# Usage:
#   get_swift_host_os(result_var_name)
#
#
# Sets ${result_var_name} with the converted OS name derived from
# CMAKE_SYSTEM_NAME.
function(get_swift_host_os result_var_name)
  if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
    set(${result_var_name} macosx PARENT_SCOPE)
  else()
    string(TOLOWER ${CMAKE_SYSTEM_NAME} cmake_system_name_lc)
    set(${result_var_name} ${cmake_system_name_lc} PARENT_SCOPE)
  endif()
endfunction()

if(NOT Swift_MODULE_TRIPLE)
  # Attempt to get the module triple from the Swift compiler.
  set(module_triple_command "${CMAKE_Swift_COMPILER}" -print-target-info)
  if(CMAKE_Swift_COMPILER_TARGET)
    list(APPEND module_triple_command -target ${CMAKE_Swift_COMPILER_TARGET})
  endif()
  execute_process(COMMAND ${module_triple_command}
    OUTPUT_VARIABLE target_info_json)
  string(JSON module_triple GET "${target_info_json}" "target" "moduleTriple")

  # Exit now if we failed to infer the triple.
  if(NOT module_triple)
    message(FATAL_ERROR
      "Failed to get module triple from Swift compiler. "
      "Compiler output: ${target_info_json}")
  endif()

  # Cache the module triple for future use.
  set(Swift_MODULE_TRIPLE "${module_triple}" CACHE STRING "swift module triple used for installed swiftmodule and swiftinterface files")
  mark_as_advanced(Swift_MODULE_TRIPLE)
endif()

function(_install_target module)
  get_swift_host_os(swift_os)
  get_target_property(type ${module} TYPE)

  if(type STREQUAL STATIC_LIBRARY)
    set(swift swift_static)
  else()
    set(swift swift)
  endif()

  install(TARGETS ${module})
  if(type STREQUAL EXECUTABLE)
    return()
  endif()

  get_target_property(module_name ${module} Swift_MODULE_NAME)
  if(NOT module_name)
    set(module_name ${module})
  endif()

  install(FILES $<TARGET_PROPERTY:${module},Swift_MODULE_DIRECTORY>/${module_name}.swiftdoc
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/${swift}/${swift_os}/${module_name}.swiftmodule
    RENAME ${Swift_MODULE_TRIPLE}.swiftdoc)
  install(FILES $<TARGET_PROPERTY:${module},Swift_MODULE_DIRECTORY>/${module_name}.swiftmodule
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/${swift}/${swift_os}/${module_name}.swiftmodule
    RENAME ${Swift_MODULE_TRIPLE}.swiftmodule)
endfunction()
