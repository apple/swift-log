if(APPLE)
  add_library(InMemoryLoggingTests MODULE
    InMemoryLogHandlerTests.swift)
  set_target_properties(InMemoryLoggingTests PROPERTIES
    BUNDLE TRUE
    BUNDLE_EXTENSION xctest)
else()
  add_executable(InMemoryLoggingTests
    InMemoryLogHandlerTests.swift)
endif()

target_compile_options(InMemoryLoggingTests PRIVATE
  ${SWIFT_LOG_COMMON_COMPILE_OPTIONS}
  "SHELL:-plugin-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing")

if(APPLE)
  find_library(TESTING_FRAMEWORK Testing
    PATHS "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"
    NO_DEFAULT_PATH)
  target_link_libraries(InMemoryLoggingTests PRIVATE InMemoryLogging Logging ${TESTING_FRAMEWORK})
else()
  target_link_libraries(InMemoryLoggingTests PRIVATE InMemoryLogging Logging Testing)
endif()

add_test(NAME InMemoryLoggingTests COMMAND InMemoryLoggingTests)
