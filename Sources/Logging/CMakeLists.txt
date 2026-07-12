add_library(Logging
  Locks.swift
  LogEvent.swift
  LogHandler.swift
  Logger+Attributes.swift
  Logger+With.swift
  Logger.swift
  LoggingSystem.swift
  MetadataProvider.swift
  Handlers/MultiplexLogHandler.swift
  Handlers/StreamLogHandler.swift
  Handlers/SwiftLogNoOpLogHandler.swift)

set_target_properties(Logging PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_Swift_MODULE_DIRECTORY})

target_compile_options(Logging PRIVATE
  -enable-upcoming-feature ExistentialAny
  -enable-upcoming-feature MemberImportVisibility
  -enable-upcoming-feature InternalImportsByDefault
  -enable-upcoming-feature NonisolatedNonsendingByDefault
  -Xfrontend -require-explicit-sendable)

_install_target(Logging)
set_property(GLOBAL APPEND PROPERTY SwiftLog_EXPORTS Logging)
