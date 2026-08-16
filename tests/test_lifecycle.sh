#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
cd "$root"

cmake --list-presets | grep -F '"debug"' >/dev/null
cmake --list-presets | grep -F '"debug-lua"' >/dev/null
cmake --list-presets | grep -F '"valgrind"' >/dev/null
for preset in x86_64-linux-gnu x86_64-linux-musl aarch64-linux-gnu aarch64-linux-musl armhf-linux-gnu armhf-linux-musl arm64-apple-darwin; do
  cmake --list-presets | grep -F "\"$preset-release\"" >/dev/null
done
grep -F '"LONEHASH_DIST_DIR": "${sourceDir}/dist"' CMakePresets.json >/dev/null
make help | grep -F 'deps-debug' >/dev/null
make help | grep -F 'valgrind' >/dev/null
make help | grep -F 'release-lua-artifacts' >/dev/null
make help | grep -F 'lua-rock' >/dev/null
make help | grep -F 'lua-source-smoke' >/dev/null
make help | grep -F 'print-release-upload-assets' >/dev/null
grep -F 'prerelease: release-pipeline' Makefile >/dev/null
grep -F 'release: clean release-pipeline' Makefile >/dev/null
grep -F 'release-pipeline: test-all lua-source-smoke package-source-smoke release-matrix' Makefile >/dev/null
grep -F '"lua == 5.5.0"' lonehash.rockspec.in >/dev/null
grep -F 'LONEHASH_VERSION_OVERRIDE' CMakeLists.txt >/dev/null
grep -F 'set(LONEHASH_HAVE_SHA_NI 0)' CMakeLists.txt >/dev/null
grep -F 'set(LONEHASH_HAVE_ARM_SHA2 0)' CMakeLists.txt >/dev/null
grep -F 'LONEHASH_HAVE_SHA_NI=$<BOOL:${LONEHASH_HAVE_SHA_NI}>' CMakeLists.txt >/dev/null
grep -F 'LONEHASH_HAVE_ARM_SHA2=$<BOOL:${LONEHASH_HAVE_ARM_SHA2}>' CMakeLists.txt >/dev/null
grep -F 'WINDOWS_EXPORT_ALL_SYMBOLS ON' CMakeLists.txt >/dev/null
grep -F 'LONEHASH_LUA_EXECUTABLE' CMakeLists.txt >/dev/null
grep -F 'LONEHASH_LUA_SOURCE_INCLUDE_DIR' CMakeLists.txt >/dev/null
grep -F 'MSVC_RUNTIME_LIBRARY' CMakeLists.txt >/dev/null
grep -F 'CMAKE_C_COMPILER_ID MATCHES "GNU|Clang" AND NOT APPLE' CMakeLists.txt >/dev/null
grep -F 'ctest --test-dir "$root/build/$preset" --output-on-failure' scripts/release_matrix.sh >/dev/null
grep -F '"$STRIP" -g "$prefix/lib/liblonehash.a"' scripts/package.sh >/dev/null
test -x scripts/stage_lua_rock_sources.sh
test -x scripts/build_lua_rock.sh

toolchain=$(scripts/cpkt-toolchains.sh discover x86_64-linux-gnu)
printf '%s\n' "$toolchain" | grep -Fx 'source=bootlin' >/dev/null
if printf '%s\n' "$toolchain" | grep '^cc=/usr/' >/dev/null; then
  echo 'lifecycle resolver selected a host compiler' >&2
  exit 1
fi
