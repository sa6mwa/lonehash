#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
cd "$root"

documented_public_symbol() {
  local header=$1 symbol=$2 macro=${3:-0}

  awk -v symbol="$symbol" -v macro="$macro" '
    /\/\*\*/ {
      comment = $0
      in_comment = ($0 !~ /\*\//)
      next
    }
    in_comment {
      comment = comment "\n" $0
      if (/\*\//) {
        in_comment = 0
      }
      next
    }
    {
      if (macro != 0) {
        symbol_pattern = "^[[:space:]]*#define[[:space:]]+" symbol "([[:space:]]|$)"
        has_symbol = ($0 ~ symbol_pattern)
      } else {
        has_symbol = (index($0, symbol) != 0)
      }
    }
    has_symbol {
      if (comment ~ /@brief/) {
        found = 1
      }
      exit
    }
    $0 !~ /^[[:space:]]*$/ { comment = "" }
    END { exit(found ? 0 : 1) }
  ' "$header"
}

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
grep -F '_CRT_SECURE_NO_WARNINGS' CMakeLists.txt >/dev/null
grep -F 'ARCHIVE_OUTPUT_NAME' CMakeLists.txt >/dev/null
grep -F 'lonehash_cli_static' CMakeLists.txt >/dev/null
grep -F 'LONEHASH_LUA_EXECUTABLE' CMakeLists.txt >/dev/null
grep -F 'LONEHASH_LUA_SOURCE_INCLUDE_DIR' CMakeLists.txt >/dev/null
grep -F 'MSVC_RUNTIME_LIBRARY' CMakeLists.txt >/dev/null
grep -F 'CMAKE_C_COMPILER_ID MATCHES "GNU|Clang" AND NOT APPLE' CMakeLists.txt >/dev/null
grep -F 'ctest --test-dir "$root/build/$preset" --output-on-failure' scripts/release_matrix.sh >/dev/null
grep -F '"$STRIP" -g "$prefix/lib/liblonehash.a"' scripts/package.sh >/dev/null
test -x scripts/stage_lua_rock_sources.sh
test -x scripts/build_lua_rock.sh
test -f include/lonehash/lonehash.h
test -f include/lonehash/lonehash_version.h.in
test ! -e include/lonehash/lonehash.h.in

for symbol in \
  LONEHASH_VERSION_MAJOR LONEHASH_VERSION_MINOR LONEHASH_VERSION_PATCH \
  LONEHASH_VERSION; do
  documented_public_symbol include/lonehash/lonehash_version.h.in "$symbol" 1 || {
    echo "public API symbol lacks a Doxygen @brief comment: $symbol" >&2
    exit 1
  }
done

for symbol in \
  LONEHASH_SHA256_DIGEST_SIZE LONEHASH_SHA256_BLOCK_SIZE \
  LONEHASH_SHA256_HEX_SIZE LONEHASH_MD5_DIGEST_SIZE LONEHASH_MD5_BLOCK_SIZE \
  LONEHASH_MD5_HEX_SIZE lonehash_status LONEHASH_OK LONEHASH_ERROR_NULL \
  LONEHASH_ERROR_ALLOC LONEHASH_ERROR_IO lonehash_sha256 lonehash_md5 \
  '(*reset)' '(*update)' '(*final)' '(*digest_buffer)' '(*digest_file)' \
  '(*digest_path)' '(*hex)' 'void *impl' lonehash_status_string \
  lonehash_sha256_create lonehash_sha256_destroy lonehash_md5_create \
  lonehash_md5_destroy; do
  documented_public_symbol include/lonehash/lonehash.h "$symbol" || {
    echo "public API symbol lacks a Doxygen @brief comment: $symbol" >&2
    exit 1
  }
done

toolchain=$(scripts/cpkt-toolchains.sh discover x86_64-linux-gnu)
printf '%s\n' "$toolchain" | grep -Fx 'source=bootlin' >/dev/null
if printf '%s\n' "$toolchain" | grep '^cc=/usr/' >/dev/null; then
  echo 'lifecycle resolver selected a host compiler' >&2
  exit 1
fi
