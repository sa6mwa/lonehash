cmake_minimum_required(VERSION 3.20)

execute_process(
  COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/scripts/release_version.sh"
  WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
  OUTPUT_VARIABLE LONEHASH_VERSION_RAW
  OUTPUT_STRIP_TRAILING_WHITESPACE
  ERROR_QUIET)
if(NOT LONEHASH_VERSION_RAW MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")
  set(LONEHASH_VERSION_RAW "0.0.0")
endif()

project(
  lonehash
  VERSION "${LONEHASH_VERSION_RAW}"
  LANGUAGES C)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

option(LONEHASH_BUILD_STATIC "Build static liblonehash" ON)
option(LONEHASH_BUILD_SHARED "Build shared liblonehash" ON)
option(LONEHASH_BUILD_EXAMPLES "Build examples" ON)
option(LONEHASH_BUILD_TESTS "Build tests" ON)
option(LONEHASH_BUILD_BENCHMARKS "Build benchmarks" ON)
option(LONEHASH_BUILD_CLI "Build lh CLI" ON)
option(LONEHASH_CLI_STATIC "Link lh fully static where the platform supports it"
       ON)
option(LONEHASH_ENABLE_SHA_NI "Enable x86 SHA-NI acceleration when available" ON)
option(LONEHASH_INSTALL "Install lonehash targets and metadata" ON)
set(LONEHASH_TARGET_ID
    "host"
    CACHE STRING "Release target identifier")
set(LONEHASH_DIST_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/dist"
    CACHE PATH "Release artifact directory")

set(CMAKE_C_STANDARD 90)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_INSTALL_RPATH "")
set(CMAKE_BUILD_RPATH "")

set(LONEHASH_VERSION "${PROJECT_VERSION}")
set(LONEHASH_VERSION_MAJOR "${PROJECT_VERSION_MAJOR}")
set(LONEHASH_VERSION_MINOR "${PROJECT_VERSION_MINOR}")
set(LONEHASH_VERSION_PATCH "${PROJECT_VERSION_PATCH}")
configure_file(include/lonehash/lonehash.h.in
               "${CMAKE_CURRENT_BINARY_DIR}/generated/include/lonehash/lonehash.h"
               @ONLY)
configure_file(cmake/lonehash.pc.in
               "${CMAKE_CURRENT_BINARY_DIR}/lonehash.pc" @ONLY)

set(LONEHASH_PUBLIC_INCLUDE_DIR
    "${CMAKE_CURRENT_BINARY_DIR}/generated/include")
set(LONEHASH_SOURCES src/lonehash.c)
if(LONEHASH_ENABLE_SHA_NI
   AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|AMD64|i[3-6]86)$"
   AND CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
  list(APPEND LONEHASH_SOURCES src/lonehash_sha256_ni.c)
  set(LONEHASH_HAVE_SHA_NI ON)
endif()

function(lonehash_target_defaults target)
  target_include_directories(
    ${target}
    PUBLIC $<BUILD_INTERFACE:${LONEHASH_PUBLIC_INCLUDE_DIR}>
           $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
  target_compile_features(${target} PUBLIC c_std_90)
  if(MSVC)
    target_compile_options(${target} PRIVATE /W4 /WX)
  else()
    target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic -Werror)
  endif()
  if(LONEHASH_HAVE_SHA_NI)
    target_compile_definitions(${target} PRIVATE LONEHASH_HAVE_SHA_NI=1)
    set_source_files_properties(src/lonehash_sha256_ni.c PROPERTIES
                                COMPILE_OPTIONS "-msha;-mssse3;-msse4.1")
  endif()
  set_target_properties(${target} PROPERTIES OUTPUT_NAME lonehash)
endfunction()

if(LONEHASH_BUILD_STATIC)
  add_library(lonehash_static STATIC ${LONEHASH_SOURCES})
  add_library(lonehash::static ALIAS lonehash_static)
  lonehash_target_defaults(lonehash_static)
  set_target_properties(lonehash_static PROPERTIES EXPORT_NAME static)
endif()

if(LONEHASH_BUILD_SHARED)
  add_library(lonehash_shared SHARED ${LONEHASH_SOURCES})
  add_library(lonehash::shared ALIAS lonehash_shared)
  lonehash_target_defaults(lonehash_shared)
  set_target_properties(
    lonehash_shared PROPERTIES VERSION "${PROJECT_VERSION}" SOVERSION 0
                               MACHO_COMPATIBILITY_VERSION 0.0.0
                               MACHO_CURRENT_VERSION "${PROJECT_VERSION}"
                               EXPORT_NAME shared)
  target_link_options(
    lonehash_shared
    PRIVATE "$<$<PLATFORM_ID:Darwin>:-Wl,-install_name,@rpath/liblonehash.0.dylib>"
  )
endif()

if(LONEHASH_BUILD_SHARED)
  add_library(lonehash ALIAS lonehash_shared)
elseif(LONEHASH_BUILD_STATIC)
  add_library(lonehash ALIAS lonehash_static)
endif()

if(LONEHASH_BUILD_EXAMPLES)
  add_executable(lonehash_example examples/hash_strings.c)
  target_link_libraries(lonehash_example PRIVATE lonehash)
  add_executable(lonehash_file_example examples/hash_file.c)
  target_link_libraries(lonehash_file_example PRIVATE lonehash)
endif()

if(LONEHASH_BUILD_CLI)
  add_executable(lh src/lh.c)
  if(MSVC)
    target_compile_options(lh PRIVATE /W4 /WX)
  else()
    target_compile_options(lh PRIVATE -Wall -Wextra -Wpedantic -Werror)
  endif()
  target_include_directories(lh PRIVATE "${LONEHASH_PUBLIC_INCLUDE_DIR}")
  if(TARGET lonehash_static)
    target_link_libraries(lh PRIVATE lonehash_static)
  else()
    target_link_libraries(lh PRIVATE lonehash)
  endif()
  if(LONEHASH_CLI_STATIC)
    target_link_options(lh PRIVATE "$<$<NOT:$<PLATFORM_ID:Darwin>>:-static>")
  endif()
endif()

if(LONEHASH_BUILD_BENCHMARKS)
  add_executable(lonehash_bench bench/bench_lonehash.c)
  target_link_libraries(lonehash_bench PRIVATE lonehash)
endif()

if(LONEHASH_BUILD_TESTS)
  enable_testing()
  add_executable(lonehash_tests tests/test_lonehash.c)
  target_link_libraries(lonehash_tests PRIVATE lonehash)
  add_test(NAME lonehash.unit COMMAND lonehash_tests)
  set_tests_properties(lonehash.unit PROPERTIES LABELS "unit;local" TIMEOUT 20)

  add_executable(lonehash_header_c89 tests/header_c89.c)
  target_link_libraries(lonehash_header_c89 PRIVATE lonehash)
  add_test(NAME lonehash.header-c89 COMMAND lonehash_header_c89)
  set_tests_properties(lonehash.header-c89 PROPERTIES LABELS "smoke;local"
                                                      TIMEOUT 10)
  if(TARGET lh)
    add_test(NAME lonehash.cli
             COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_lh_cli.sh"
                     "$<TARGET_FILE:lh>")
    set_tests_properties(lonehash.cli PROPERTIES LABELS "smoke;local" TIMEOUT
                                                 10)
  endif()
endif()

if(LONEHASH_INSTALL)
  install(FILES "${LONEHASH_PUBLIC_INCLUDE_DIR}/lonehash/lonehash.h"
          DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/lonehash")
  set(export_targets)
  if(TARGET lonehash_static)
    list(APPEND export_targets lonehash_static)
  endif()
  if(TARGET lonehash_shared)
    list(APPEND export_targets lonehash_shared)
  endif()
  install(
    TARGETS ${export_targets}
    EXPORT lonehashTargets
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
  install(EXPORT lonehashTargets
          NAMESPACE lonehash::
          DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/lonehash")
  write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/lonehashConfigVersion.cmake"
    VERSION "${PROJECT_VERSION}"
    COMPATIBILITY SameMajorVersion)
  configure_package_config_file(
    cmake/lonehashConfig.cmake.in
    "${CMAKE_CURRENT_BINARY_DIR}/lonehashConfig.cmake"
    INSTALL_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/lonehash")
  install(FILES "${CMAKE_CURRENT_BINARY_DIR}/lonehashConfig.cmake"
                "${CMAKE_CURRENT_BINARY_DIR}/lonehashConfigVersion.cmake"
          DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/lonehash")
  install(FILES "${CMAKE_CURRENT_BINARY_DIR}/lonehash.pc"
          DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")
  install(FILES LICENSE README.md DESTINATION "${CMAKE_INSTALL_DOCDIR}")
endif()
