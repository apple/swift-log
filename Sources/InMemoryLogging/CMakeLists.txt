add_library(InMemoryLogging
  InMemoryLogHandler.swift)

set_target_properties(InMemoryLogging PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES "$<BUILD_INTERFACE:$<TARGET_PROPERTY:Swift_MODULE_DIRECTORY>>;$<BUILD_INTERFACE:$<TARGET_FILE_DIR:InMemoryLogging>>")

target_compile_options(InMemoryLogging PRIVATE
  ${SWIFT_LOG_COMMON_COMPILE_OPTIONS}
  "$<$<BOOL:${BUILD_TESTING}>:SHELL:-enable-testing>")

target_link_libraries(InMemoryLogging PRIVATE Logging)

_install_target(InMemoryLogging)
set_property(GLOBAL APPEND PROPERTY SwiftLog_EXPORTS InMemoryLogging)
