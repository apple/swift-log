set(SwiftLog_EXPORTS_FILE ${CMAKE_CURRENT_BINARY_DIR}/SwiftLogExports.cmake)

configure_file(SwiftLogConfig.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/SwiftLogConfig.cmake)

get_property(SwiftLog_EXPORTS GLOBAL PROPERTY SwiftLog_EXPORTS)
export(TARGETS ${SwiftLog_EXPORTS}
  FILE ${SwiftLog_EXPORTS_FILE})
