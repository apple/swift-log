add_library(Logging
  "Handlers/MultiplexLogHandler.swift"
  "Handlers/StreamLogHandler.swift"
  "Handlers/SwiftLogNoOpLogHandler.swift"
  "Locks.swift"
  "LogEvent.swift"
  "LogHandler.swift"
  "Logger+Attributes.swift"
  "Logger+With.swift"
  "Logger.swift"
  "LoggingSystem.swift"
  "MetadataProvider.swift"
)

set_target_properties(Logging PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES "$<BUILD_INTERFACE:$<TARGET_PROPERTY:Swift_MODULE_DIRECTORY>>;$<BUILD_INTERFACE:$<TARGET_FILE_DIR:Logging>>")

target_compile_options(Logging PRIVATE
  ${SWIFT_LOG_COMMON_COMPILE_OPTIONS}
  "$<$<BOOL:${BUILD_TESTING}>:SHELL:-enable-testing>")

_install_target(Logging)
set_property(GLOBAL APPEND PROPERTY SwiftLog_EXPORTS Logging)
