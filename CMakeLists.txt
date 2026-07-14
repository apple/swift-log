cmake_minimum_required(VERSION 3.19)

# Enable C and Swift languages
project(swift-log
  LANGUAGES C Swift)

option(BUILD_TESTING "Build testing targets" ON)
option(BUILD_SHARED_LIBS "Build shared libraries by default" YES)

set(CMAKE_Swift_LANGUAGE_VERSION 6)

set(SWIFT_LOG_COMMON_COMPILE_OPTIONS
  "SHELL:-enable-upcoming-feature ExistentialAny"
  "SHELL:-enable-upcoming-feature MemberImportVisibility"
  "SHELL:-enable-upcoming-feature InternalImportsByDefault"
  "SHELL:-enable-upcoming-feature NonisolatedNonsendingByDefault"
  "SHELL:-Xfrontend -require-explicit-sendable"
  "SHELL:-package-name swift_log")

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)

if(MSVC)
  set(CMAKE_Swift_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
endif()

include(CTest)
include(GNUInstallDirs)
include(SwiftSupport)

if(NOT APPLE)
  find_package(dispatch QUIET)
  find_package(Foundation QUIET)
endif()

add_subdirectory(Sources)
if(BUILD_TESTING)
  add_subdirectory(Tests)
endif()

add_subdirectory(cmake/modules)
