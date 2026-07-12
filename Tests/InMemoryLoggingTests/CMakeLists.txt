add_executable(InMemoryLoggingTests
  InMemoryLogHandlerTests.swift)

target_compile_options(InMemoryLoggingTests PRIVATE
  -enable-upcoming-feature ExistentialAny
  -enable-upcoming-feature MemberImportVisibility
  -enable-upcoming-feature InternalImportsByDefault
  -enable-upcoming-feature NonisolatedNonsendingByDefault
  -Xfrontend -require-explicit-sendable)

target_link_libraries(InMemoryLoggingTests PRIVATE InMemoryLogging Logging)
if(NOT APPLE)
  if(XCTest_FOUND)
    target_link_libraries(InMemoryLoggingTests PRIVATE XCTest)
  endif()
endif()

add_test(NAME InMemoryLoggingTests COMMAND InMemoryLoggingTests)
