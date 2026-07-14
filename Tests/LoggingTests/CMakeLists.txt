if(APPLE)
  add_library(LoggingTests MODULE
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
    TestSendable.swift
    SubDirectoryOfLoggingTests/EmitALogFromSubDirectory.swift)
  set_target_properties(LoggingTests PROPERTIES
    BUNDLE TRUE
    BUNDLE_EXTENSION xctest)
else()
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
    TestSendable.swift
    SubDirectoryOfLoggingTests/EmitALogFromSubDirectory.swift)
endif()

target_compile_options(LoggingTests PRIVATE
  ${SWIFT_LOG_COMMON_COMPILE_OPTIONS}
  "SHELL:-plugin-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing")

if(APPLE)
  find_library(TESTING_FRAMEWORK Testing
    PATHS "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks"
          "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"
    NO_DEFAULT_PATH)
  target_link_libraries(LoggingTests PRIVATE Logging ${TESTING_FRAMEWORK})
else()
  target_link_libraries(LoggingTests PRIVATE Logging Testing)
endif()

add_test(NAME LoggingTests COMMAND LoggingTests)
