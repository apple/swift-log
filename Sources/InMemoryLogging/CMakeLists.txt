add_library(InMemoryLogging
  InMemoryLogHandler.swift)

set_target_properties(InMemoryLogging PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_Swift_MODULE_DIRECTORY})

target_compile_options(InMemoryLogging PRIVATE
  -enable-upcoming-feature ExistentialAny
  -enable-upcoming-feature MemberImportVisibility
  -enable-upcoming-feature InternalImportsByDefault
  -enable-upcoming-feature NonisolatedNonsendingByDefault
  -Xfrontend -require-explicit-sendable)

target_link_libraries(InMemoryLogging PRIVATE Logging)

_install_target(InMemoryLogging)
set_property(GLOBAL APPEND PROPERTY SwiftLog_EXPORTS InMemoryLogging)
