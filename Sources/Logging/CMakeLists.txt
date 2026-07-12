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
  INTERFACE_INCLUDE_DIRECTORIES "$<BUILD_INTERFACE:$<TARGET_PROPERTY:Swift_MODULE_DIRECTORY>>;$<BUILD_INTERFACE:$<TARGET_FILE_DIR:Logging>>")

target_compile_options(Logging PRIVATE
  "SHELL:-enable-upcoming-feature ExistentialAny"
  "SHELL:-enable-upcoming-feature MemberImportVisibility"
  "SHELL:-enable-upcoming-feature InternalImportsByDefault"
  "SHELL:-enable-upcoming-feature NonisolatedNonsendingByDefault"
  "SHELL:-Xfrontend -require-explicit-sendable"
  "SHELL:-package-name swift_log"
  "$<$<BOOL:${BUILD_TESTING}>:SHELL:-enable-testing>")

_install_target(Logging)
set_property(GLOBAL APPEND PROPERTY SwiftLog_EXPORTS Logging)
