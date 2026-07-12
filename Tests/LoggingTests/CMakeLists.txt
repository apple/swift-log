add_executable(LoggingTests
  CompatibilityTest.swift
  GlobalLoggingTest.swift
  LocalLoggingTest.swift
  LockTest.swift
  LogEventTest.swift
  LoggingTest.swift
  MDCTest.swift
  MetadataAttributesTest.swift
  MetadataProviderTest.swift
  MetadataValueInterpolationTest.swift
  StreamLogHandlerTest.swift
  SwiftLogNoOpLogHandlerTest.swift
  TaskLocalLoggerTest.swift
  TestLogger.swift
  TestSendable.swift)

target_compile_options(LoggingTests PRIVATE
  -enable-upcoming-feature ExistentialAny
  -enable-upcoming-feature MemberImportVisibility
  -enable-upcoming-feature InternalImportsByDefault
  -enable-upcoming-feature NonisolatedNonsendingByDefault
  -Xfrontend -require-explicit-sendable)

target_link_libraries(LoggingTests PRIVATE Logging)
if(NOT APPLE)
  if(XCTest_FOUND)
    target_link_libraries(LoggingTests PRIVATE XCTest)
  endif()
endif()

add_test(NAME LoggingTests COMMAND LoggingTests)
