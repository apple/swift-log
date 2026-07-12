add_library(InMemoryLogging
  InMemoryLogHandler.swift)

set_target_properties(InMemoryLogging PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES "$<BUILD_INTERFACE:$<TARGET_PROPERTY:Swift_MODULE_DIRECTORY>>;$<BUILD_INTERFACE:$<TARGET_FILE_DIR:InMemoryLogging>>")

target_compile_options(InMemoryLogging PRIVATE
  "SHELL:-enable-upcoming-feature ExistentialAny"
  "SHELL:-enable-upcoming-feature MemberImportVisibility"
  "SHELL:-enable-upcoming-feature InternalImportsByDefault"
  "SHELL:-enable-upcoming-feature NonisolatedNonsendingByDefault"
  "SHELL:-Xfrontend -require-explicit-sendable"
  "SHELL:-package-name swift_log"
  "$<$<BOOL:${BUILD_TESTING}>:SHELL:-enable-testing>")

target_link_libraries(InMemoryLogging PRIVATE Logging)

_install_target(InMemoryLogging)
set_property(GLOBAL APPEND PROPERTY SwiftLog_EXPORTS InMemoryLogging)
