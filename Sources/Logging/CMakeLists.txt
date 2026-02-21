add_library(Logging
  Locks.swift
  Logging.swift
  LogHandler.swift)
target_compile_options(Logging PRIVATE
  "SHELL:$<$<PLATFORM_ID:Windows>:-Xcc -D_CRT_SECURE_NO_WARNINGS>")
set_target_properties(Logging PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_Swift_MODULE_DIRECTORY})


swift_install(TARGETS Logging
  EXPORT swift-log)
