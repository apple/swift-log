
include(CMakeParseArguments)

# Returns the architecture name in a variable
#
# Usage:
#   swift_get_host_arch(result_var_name)
#
# Sets ${result_var_name} with the converted architecture name derived from
# CMAKE_SYSTEM_PROCESSOR.
function(swift_get_host_arch result_var_name)
  if("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "x86_64")
    set("${result_var_name}" "x86_64" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "aarch64")
    set("${result_var_name}" "aarch64" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "ppc64")
    set("${result_var_name}" "powerpc64" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "ppc64le")
    set("${result_var_name}" "powerpc64le" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "s390x")
    set("${result_var_name}" "s390x" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "armv6l")
    set("${result_var_name}" "armv6" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "armv7l")
    set("${result_var_name}" "armv7" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "armv7-a")
    set("${result_var_name}" "armv7" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "AMD64")
    set("${result_var_name}" "x86_64" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "IA64")
    set("${result_var_name}" "itanium" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "x86")
    set("${result_var_name}" "i686" PARENT_SCOPE)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "i686")
    set("${result_var_name}" "i686" PARENT_SCOPE)
  else()
    message(FATAL_ERROR "Unrecognized architecture on host system: ${CMAKE_SYSTEM_PROCESSOR}")
  endif()
endfunction()

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

function(swift_install)
  set(options)
  set(single_parameter_options EXPORT)
  set(multiple_parameter_options TARGETS)

  cmake_parse_arguments(SI
    "${options}"
    "${single_parameter_options}"
    "${multiple_parameter_options}"
    ${ARGN})

  list(LENGTH ${SI_TARGETS} si_num_targets)
  if(si_num_targets GREATER 1)
    message(SEND_ERROR "swift_install only supports a single target at a time")
  endif()

  get_swift_host_os(swift_os)
  get_target_property(type ${SI_TARGETS} TYPE)

  if(type STREQUAL STATIC_LIBRARY)
    set(swift_dir swift_static)
  else()
    set(swift_dir swift)
  endif()

  install(TARGETS ${SI_TARGETS}
    EXPORT ${SI_EXPORT}
    ARCHIVE DESTINATION lib/${swift_dir}/${swift_os}
    LIBRARY DESTINATION lib/${swift_dir}/${swift_os}
    RUNTIME DESTINATION bin)
  if(type STREQUAL EXECUTABLE)
    return()
  endif()

  swift_get_host_arch(swift_arch)
  get_target_property(module_name ${SI_TARGETS} Swift_MODULE_NAME)
  if(NOT module_name)
    set(module_name ${SI_TARGETS})
  endif()

  if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
    install(FILES
      $<TARGET_PROPERTY:${SI_TARGETS},Swift_MODULE_DIRECTORY>/${module_name}.swiftdoc
      DESTINATION lib/${swift_dir}/${swift_os}/${module_name}.swiftmodule
      RENAME ${swift_arch}.swiftdoc)
    install(FILES
      $<TARGET_PROPERTY:${SI_TARGETS},Swift_MODULE_DIRECTORY>/${module_name}.swiftmodule
      DESTINATION lib/${swift_dir}/${swift_os}/${module_name}.swiftmodule
      RENAME ${swift_arch}.swiftmodule)
  else()
    install(FILES
      $<TARGET_PROPERTY:${SI_TARGETS},Swift_MODULE_DIRECTORY>/${module_name}.swiftdoc
      $<TARGET_PROPERTY:${SI_TARGETS},Swift_MODULE_DIRECTORY>/${module_name}.swiftmodule
      DESTINATION lib/${swift_dir}/${swift_os}/${swift_arch})
  endif()
endfunction()
