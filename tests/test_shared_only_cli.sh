#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
build="$root/.cache/shared-only-cli-test"

rm -rf "$build"
trap 'rm -rf "$build"' EXIT HUP INT TERM
cmake -S "$root" -B "$build" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$root/cmake/toolchains/lonehash-cross.cmake" \
  -DLONEHASH_TARGET_ID=x86_64-linux-gnu \
  -DLONEHASH_BUILD_STATIC=OFF \
  -DLONEHASH_BUILD_SHARED=ON \
  -DLONEHASH_BUILD_CLI=ON \
  -DLONEHASH_BUILD_BENCHMARKS=OFF \
  -DLONEHASH_BUILD_EXAMPLES=OFF \
  -DLONEHASH_BUILD_LUA=OFF \
  -DLONEHASH_BUILD_TESTS=OFF
cmake --build "$build" --target lh
test -x "$build/lh"
