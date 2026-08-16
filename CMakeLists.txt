cmake_minimum_required(VERSION 3.20)

set(LONEHASH_VERSION_OVERRIDE
    ""
    CACHE STRING "Explicit semver version for a local release-candidate build")
set(_lonehash_version_command "${CMAKE_CURRENT_SOURCE_DIR}/scripts/release_version.sh")
if(NOT LONEHASH_VERSION_OVERRIDE STREQUAL "")
  set(_lonehash_version_command "${CMAKE_COMMAND}" "-E" "env"
                                "LONEHASH_VERSION_OVERRIDE=${LONEHASH_VERSION_OVERRIDE}"
                                "${CMAKE_CURRENT_SOURCE_DIR}/scripts/release_version.sh")
endif()
execute_process(
  COMMAND ${_lonehash_version_command}
  WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
  RESULT_VARIABLE LONEHASH_VERSION_RESULT
  OUTPUT_VARIABLE LONEHASH_VERSION_RAW
  OUTPUT_STRIP_TRAILING_WHITESPACE
  ERROR_VARIABLE LONEHASH_VERSION_ERROR)
if(NOT LONEHASH_VERSION_RESULT EQUAL 0)
  message(FATAL_ERROR "Unable to resolve lonehash version: ${LONEHASH_VERSION_ERROR}")
endif()
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
option(LONEHASH_BUILD_LUA "Build Lua facade for the host build" OFF)
option(LONEHASH_CLI_STATIC "Link lh fully static where the platform supports it"
       ON)
option(LONEHASH_ENABLE_SHA_NI "Enable x86 SHA-NI acceleration when available" ON)
option(LONEHASH_ENABLE_ARM_SHA2
       "Enable AArch64 SHA2 acceleration when available" ON)
option(LONEHASH_INSTALL "Install lonehash targets and metadata" ON)
set(LONEHASH_TARGET_ID
    "x86_64-linux-gnu"
    CACHE STRING "Release target identifier")
set(LONEHASH_DIST_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/dist"
    CACHE PATH "Release artifact directory")

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_INSTALL_RPATH "")
set(CMAKE_BUILD_RPATH "")

set(LONEHASH_VERSION "${PROJECT_VERSION}")
set(LONEHASH_VERSION_MAJOR "${PROJECT_VERSION_MAJOR}")
set(LONEHASH_VERSION_MINOR "${PROJECT_VERSION_MINOR}")
set(LONEHASH_VERSION_PATCH "${PROJECT_VERSION_PATCH}")
set(LONEHASH_GENERATED_INCLUDE_DIR
    "${CMAKE_CURRENT_BINARY_DIR}/generated/include")
set(LONEHASH_SOURCE_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include")
file(REMOVE "${LONEHASH_GENERATED_INCLUDE_DIR}/lonehash/lonehash.h")
configure_file(include/lonehash/lonehash_version.h.in
               "${LONEHASH_GENERATED_INCLUDE_DIR}/lonehash/lonehash_version.h"
               @ONLY)
configure_file(cmake/lonehash.pc.in
               "${CMAKE_CURRENT_BINARY_DIR}/lonehash.pc" @ONLY)

set(LONEHASH_SOURCES src/lonehash.c)
set(LONEHASH_HAVE_SHA_NI 0)
set(LONEHASH_HAVE_ARM_SHA2 0)
set(LONEHASH_SHA_NI_TARGET OFF)
set(LONEHASH_ARM_SHA2_TARGET OFF)
if(LONEHASH_TARGET_ID STREQUAL "x86_64-linux-gnu")
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|AMD64|i[3-6]86)$")
    set(LONEHASH_SHA_NI_TARGET ON)
  endif()
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64|ARM64)$")
    set(LONEHASH_ARM_SHA2_TARGET ON)
  endif()
elseif(LONEHASH_TARGET_ID MATCHES "^(x86_64|i[3-6]86)-")
  set(LONEHASH_SHA_NI_TARGET ON)
elseif(LONEHASH_TARGET_ID MATCHES "^(aarch64|arm64)-")
  set(LONEHASH_ARM_SHA2_TARGET ON)
endif()
if(LONEHASH_ENABLE_SHA_NI
   AND LONEHASH_SHA_NI_TARGET
   AND CMAKE_C_COMPILER_ID MATCHES "GNU|Clang"
   AND NOT MSVC)
  list(APPEND LONEHASH_SOURCES src/lonehash_sha256_ni.c)
  set(LONEHASH_HAVE_SHA_NI ON)
endif()
if(LONEHASH_ENABLE_ARM_SHA2
   AND LONEHASH_ARM_SHA2_TARGET
   AND CMAKE_C_COMPILER_ID MATCHES "GNU|Clang"
   AND NOT MSVC)
  list(APPEND LONEHASH_SOURCES src/lonehash_sha256_armv8.c)
  set(LONEHASH_HAVE_ARM_SHA2 ON)
endif()

function(lonehash_configure_c89_target target)
  if(MSVC)
    target_compile_definitions(${target} PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_compile_options(${target} PRIVATE /W4 /WX)
  elseif(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
    target_compile_options(${target} PRIVATE -std=c89 -Wall -Wextra -Wpedantic
                                             -pedantic-errors -Werror)
  endif()
  get_property(lonehash_target_type TARGET ${target} PROPERTY TYPE)
  if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|AppleClang"
     AND NOT APPLE
     AND NOT MSVC
     AND (lonehash_target_type STREQUAL "EXECUTABLE"
          OR lonehash_target_type STREQUAL "SHARED_LIBRARY"
          OR lonehash_target_type STREQUAL "MODULE_LIBRARY"))
    target_link_options(${target} PRIVATE -Wl,--fatal-warnings)
  endif()
endfunction()

function(lonehash_target_defaults target)
  target_include_directories(
    ${target}
    PUBLIC $<BUILD_INTERFACE:${LONEHASH_GENERATED_INCLUDE_DIR}>
           $<BUILD_INTERFACE:${LONEHASH_SOURCE_INCLUDE_DIR}>
           $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
  target_compile_definitions(
    ${target} PRIVATE LONEHASH_HAVE_SHA_NI=$<BOOL:${LONEHASH_HAVE_SHA_NI}>
                      LONEHASH_HAVE_ARM_SHA2=$<BOOL:${LONEHASH_HAVE_ARM_SHA2}>)
  lonehash_configure_c89_target(${target})
  if(LONEHASH_HAVE_SHA_NI)
    set_source_files_properties(src/lonehash_sha256_ni.c PROPERTIES
                                COMPILE_OPTIONS "-msha;-mssse3;-msse4.1")
  endif()
  if(LONEHASH_HAVE_ARM_SHA2)
    if(NOT LONEHASH_TARGET_ID MATCHES "apple-darwin$")
      set_source_files_properties(src/lonehash_sha256_armv8.c PROPERTIES
                                  COMPILE_OPTIONS "-march=armv8-a+crypto")
    endif()
  endif()
  set_target_properties(${target} PROPERTIES OUTPUT_NAME lonehash)
endfunction()

if(LONEHASH_BUILD_STATIC)
  add_library(lonehash_static STATIC ${LONEHASH_SOURCES})
  add_library(lonehash::static ALIAS lonehash_static)
  lonehash_target_defaults(lonehash_static)
  set_target_properties(lonehash_static PROPERTIES EXPORT_NAME static)
  if(WIN32)
    set_target_properties(lonehash_static PROPERTIES ARCHIVE_OUTPUT_NAME
                                                     lonehash_static)
  endif()
endif()

if(LONEHASH_BUILD_SHARED)
  add_library(lonehash_shared SHARED ${LONEHASH_SOURCES})
  add_library(lonehash::shared ALIAS lonehash_shared)
  lonehash_target_defaults(lonehash_shared)
  set_target_properties(
    lonehash_shared PROPERTIES VERSION "${PROJECT_VERSION}" SOVERSION 0
                               MACHO_COMPATIBILITY_VERSION 0.0.0
                               MACHO_CURRENT_VERSION "${PROJECT_VERSION}"
                               WINDOWS_EXPORT_ALL_SYMBOLS ON
                               EXPORT_NAME shared)
  if(WIN32)
    set_target_properties(lonehash_shared PROPERTIES ARCHIVE_OUTPUT_NAME lonehash)
  endif()
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
  lonehash_configure_c89_target(lonehash_example)
  target_link_libraries(lonehash_example PRIVATE lonehash)
  add_executable(lonehash_file_example examples/hash_file.c)
  lonehash_configure_c89_target(lonehash_file_example)
  target_link_libraries(lonehash_file_example PRIVATE lonehash)
endif()

if(LONEHASH_BUILD_CLI)
  add_executable(lh src/lh.c)
  lonehash_configure_c89_target(lh)
  target_include_directories(lh PRIVATE "${LONEHASH_GENERATED_INCLUDE_DIR}"
                                         "${LONEHASH_SOURCE_INCLUDE_DIR}")
  if(TARGET lonehash_static)
    if(LONEHASH_CLI_STATIC AND MSVC)
      add_library(lonehash_cli_static STATIC ${LONEHASH_SOURCES})
      lonehash_target_defaults(lonehash_cli_static)
      set_target_properties(lonehash_cli_static PROPERTIES OUTPUT_NAME
                                                          lonehash_cli_static
                                                          MSVC_RUNTIME_LIBRARY
                                                          "MultiThreaded$<$<CONFIG:Debug>:Debug>")
      set_property(TARGET lh PROPERTY MSVC_RUNTIME_LIBRARY
                                      "MultiThreaded$<$<CONFIG:Debug>:Debug>")
      target_link_libraries(lh PRIVATE lonehash_cli_static)
    else()
      target_link_libraries(lh PRIVATE lonehash_static)
    endif()
  else()
    target_link_libraries(lh PRIVATE lonehash)
  endif()
  if(LONEHASH_CLI_STATIC AND TARGET lonehash_static)
    if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang" AND NOT APPLE AND NOT MSVC)
      target_link_options(lh PRIVATE -static)
    endif()
  endif()
endif()

if(LONEHASH_BUILD_LUA)
  if(NOT TARGET lonehash_shared)
    message(FATAL_ERROR "LONEHASH_BUILD_LUA requires LONEHASH_BUILD_SHARED=ON")
  endif()
  find_program(LONEHASH_LUA_EXECUTABLE NAMES lua5.5 lua-5.5 lua REQUIRED
               NO_CMAKE_FIND_ROOT_PATH)
  execute_process(
    COMMAND "${LONEHASH_LUA_EXECUTABLE}" -e "io.write(_VERSION)"
    RESULT_VARIABLE LONEHASH_LUA_VERSION_RESULT
    OUTPUT_VARIABLE LONEHASH_LUA_INTERPRETER_VERSION
    ERROR_VARIABLE LONEHASH_LUA_VERSION_ERROR
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT LONEHASH_LUA_VERSION_RESULT EQUAL 0
     OR NOT LONEHASH_LUA_INTERPRETER_VERSION STREQUAL "Lua 5.5")
    message(
      FATAL_ERROR
        "${LONEHASH_LUA_EXECUTABLE} is not a Lua 5.5 interpreter: ${LONEHASH_LUA_VERSION_ERROR}"
    )
  endif()
  find_path(LONEHASH_LUA_SOURCE_INCLUDE_DIR lua.h
            PATHS /usr/local/include /usr/include
            PATH_SUFFIXES lua5.5 lua-5.5
            REQUIRED NO_CMAKE_FIND_ROOT_PATH)
  file(STRINGS "${LONEHASH_LUA_SOURCE_INCLUDE_DIR}/lua.h"
       LONEHASH_LUA_HEADER_MAJOR
       REGEX "LUA_VERSION_MAJOR_N.*5")
  file(STRINGS "${LONEHASH_LUA_SOURCE_INCLUDE_DIR}/lua.h"
       LONEHASH_LUA_HEADER_MINOR
       REGEX "LUA_VERSION_MINOR_N.*5")
  if(LONEHASH_LUA_HEADER_MAJOR STREQUAL ""
     OR LONEHASH_LUA_HEADER_MINOR STREQUAL "")
    message(
      FATAL_ERROR
        "${LONEHASH_LUA_SOURCE_INCLUDE_DIR} does not provide Lua 5.5 headers for ${LONEHASH_LUA_EXECUTABLE}"
    )
  endif()
  if(WIN32)
    get_filename_component(LONEHASH_LUA_EXECUTABLE_DIR
                           "${LONEHASH_LUA_EXECUTABLE}" DIRECTORY)
    find_library(LONEHASH_LUA_LIBRARY
                 NAMES lua5.5 lua-5.5 lua55 lua
                 HINTS "${LONEHASH_LUA_EXECUTABLE_DIR}/../lib"
                 PATHS /usr/local/lib /usr/lib
                 PATH_SUFFIXES lua5.5 lua-5.5
                 REQUIRED NO_CMAKE_FIND_ROOT_PATH)
  endif()
  set(LONEHASH_LUA_INCLUDE_DIR
      "${CMAKE_CURRENT_BINARY_DIR}/generated/host-lua-include")
  file(COPY "${LONEHASH_LUA_SOURCE_INCLUDE_DIR}/"
       DESTINATION "${LONEHASH_LUA_INCLUDE_DIR}" FILES_MATCHING PATTERN "*.h")
  add_library(lonehash_lua_core MODULE lua/lonehash/core.c)
  target_include_directories(lonehash_lua_core
                             PRIVATE "${LONEHASH_LUA_INCLUDE_DIR}"
                                     "${LONEHASH_GENERATED_INCLUDE_DIR}"
                                     "${LONEHASH_SOURCE_INCLUDE_DIR}")
  target_link_libraries(lonehash_lua_core PRIVATE lonehash_shared)
  if(WIN32)
    target_link_libraries(lonehash_lua_core PRIVATE "${LONEHASH_LUA_LIBRARY}")
  endif()
  set_target_properties(lonehash_lua_core PROPERTIES C_STANDARD 99
                                                     C_STANDARD_REQUIRED ON)
  if(MSVC)
    target_compile_options(lonehash_lua_core PRIVATE /W4 /WX)
  else()
    target_compile_options(lonehash_lua_core PRIVATE -Wall -Wextra -Wpedantic
                                                     -Werror)
  endif()
  get_property(lonehash_lua_type TARGET lonehash_lua_core PROPERTY TYPE)
  if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|AppleClang" AND NOT APPLE AND NOT MSVC
     AND lonehash_lua_type STREQUAL "MODULE_LIBRARY")
    target_link_options(lonehash_lua_core PRIVATE -Wl,--fatal-warnings)
  endif()
  set_target_properties(
    lonehash_lua_core
    PROPERTIES PREFIX ""
               OUTPUT_NAME core
               LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lonehash"
               RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lonehash"
               BUILD_RPATH "$ORIGIN/..")
  configure_file(cmake/lh.sh.in "${CMAKE_CURRENT_BINARY_DIR}/lh.sh" @ONLY)
  file(CHMOD "${CMAKE_CURRENT_BINARY_DIR}/lh.sh"
       FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ
                        GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
endif()

if(LONEHASH_BUILD_BENCHMARKS)
  add_executable(lonehash_bench bench/bench_lonehash.c)
  lonehash_configure_c89_target(lonehash_bench)
  target_link_libraries(lonehash_bench PRIVATE lonehash)
endif()

if(LONEHASH_BUILD_TESTS)
  enable_testing()
  find_package(Threads REQUIRED)
  add_executable(lonehash_tests tests/test_lonehash.c)
  lonehash_configure_c89_target(lonehash_tests)
  target_link_libraries(lonehash_tests PRIVATE lonehash Threads::Threads)
  add_test(NAME lonehash.unit COMMAND lonehash_tests)
  set_tests_properties(lonehash.unit PROPERTIES LABELS "unit;local" TIMEOUT 60)

  add_executable(lonehash_header_c89 tests/header_c89.c)
  lonehash_configure_c89_target(lonehash_header_c89)
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
    add_test(NAME lonehash.shared-only-cli
             COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_shared_only_cli.sh"
                     "${CMAKE_CURRENT_SOURCE_DIR}")
    set_tests_properties(lonehash.shared-only-cli PROPERTIES LABELS "local;lifecycle"
                                                             TIMEOUT 20)
  endif()
  if(LONEHASH_HAVE_SHA_NI)
    add_executable(lonehash_sha_ni_features tests/test_sha256_ni_features.c)
    lonehash_configure_c89_target(lonehash_sha_ni_features)
    target_compile_options(lonehash_sha_ni_features PRIVATE -msha -mssse3 -msse4.1)
    add_test(NAME lonehash.sha-ni-features COMMAND lonehash_sha_ni_features)
    set_tests_properties(lonehash.sha-ni-features PROPERTIES LABELS "unit;local"
                                                               TIMEOUT 10)
  endif()
  if(TARGET lonehash_lua_core)
    add_test(NAME lonehash.lua
             COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_lua.sh"
                     "${CMAKE_CURRENT_SOURCE_DIR}"
                     "${CMAKE_CURRENT_BINARY_DIR}")
    set_tests_properties(lonehash.lua PROPERTIES LABELS "smoke;local;lua"
                                                 TIMEOUT 10)
  endif()
  add_test(NAME lonehash.lifecycle
           COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_lifecycle.sh"
                   "${CMAKE_CURRENT_SOURCE_DIR}")
  set_tests_properties(lonehash.lifecycle PROPERTIES LABELS "local;lifecycle"
                                                   TIMEOUT 20)
  add_test(NAME lonehash.release-version
           COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_release_version.sh"
                   "${CMAKE_CURRENT_SOURCE_DIR}")
  set_tests_properties(lonehash.release-version PROPERTIES LABELS "local;lifecycle"
                                                         TIMEOUT 20)
  add_test(NAME lonehash.release-upload-assets
           COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_release_upload_args.sh"
                   "${CMAKE_CURRENT_SOURCE_DIR}")
  set_tests_properties(lonehash.release-upload-assets PROPERTIES LABELS "local;lifecycle"
                                                               TIMEOUT 20)
  add_test(NAME lonehash.lua-artifact-validation
           COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_lua_artifact_validation.sh"
                   "${CMAKE_CURRENT_SOURCE_DIR}")
  set_tests_properties(lonehash.lua-artifact-validation PROPERTIES LABELS "local;lifecycle;lua"
                                                                   TIMEOUT 20)
  add_test(NAME lonehash.lua-rock-regeneration
           COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_lua_rock_regeneration.sh"
                   "${CMAKE_CURRENT_SOURCE_DIR}")
  set_tests_properties(lonehash.lua-rock-regeneration PROPERTIES LABELS "local;lifecycle;lua"
                                                               TIMEOUT 20)
  add_test(NAME lonehash.source-package-nested
           COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_source_package_nested.sh"
                   "${CMAKE_CURRENT_SOURCE_DIR}")
  set_tests_properties(lonehash.source-package-nested PROPERTIES LABELS "local;lifecycle"
                                                               TIMEOUT 20)
  add_test(NAME lonehash.toolchain-env-escaping
           COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_toolchain_env_escaping.sh"
                   "${CMAKE_CURRENT_SOURCE_DIR}")
  set_tests_properties(lonehash.toolchain-env-escaping PROPERTIES LABELS "local;lifecycle"
                                                                 TIMEOUT 20)
  add_test(NAME lonehash.package-checksums-assets
           COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_package_checksums_assets.sh"
                   "${CMAKE_CURRENT_SOURCE_DIR}")
  set_tests_properties(lonehash.package-checksums-assets PROPERTIES LABELS "local;lifecycle"
                                                                   TIMEOUT 20)
  add_test(NAME lonehash.apple-toolchain-discovery
           COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_apple_toolchain_discovery.sh"
                   "${CMAKE_CURRENT_SOURCE_DIR}")
  set_tests_properties(lonehash.apple-toolchain-discovery PROPERTIES LABELS "local;lifecycle"
                                                                    TIMEOUT 20)
endif()

if(LONEHASH_INSTALL)
  install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/lonehash/lonehash.h"
                "${LONEHASH_GENERATED_INCLUDE_DIR}/lonehash/lonehash_version.h"
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
