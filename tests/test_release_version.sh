#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
cd "$root"
tmp="$root/.cache/release-version-test"
rm -rf "$tmp"
trap 'rm -rf "$tmp"; git tag -d v99.99.99 v99.99.99-local >/dev/null 2>&1 || true' EXIT HUP INT TERM

assert_cmake_version() {
  local build=$1 expected=$2
  cmake -S "$root" -B "$build" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$root/cmake/toolchains/lonehash-cross.cmake" \
    -DLONEHASH_TARGET_ID=x86_64-linux-gnu \
    -DLONEHASH_VERSION_OVERRIDE="${3:-}" >/dev/null
  grep -F "#define LONEHASH_VERSION \"$expected\"" \
    "$build/generated/include/lonehash/lonehash.h" >/dev/null
}

if test "$(git rev-parse --show-toplevel 2>/dev/null || true)" != "$root"; then
  test "$(scripts/release_version.sh)" = "$(sed -n '1p' VERSION)"
  assert_cmake_version "$tmp/source" "$(sed -n '1p' VERSION)"
  exit 0
fi

test "$(LONEHASH_VERSION_OVERRIDE=7.8.9 scripts/release_version.sh)" = 7.8.9
test "$(LONEHASH_VERSION_OVERRIDE=7.8.9 make --silent print-release-version)" = 7.8.9
assert_cmake_version "$tmp/override" 7.8.9 7.8.9
if LONEHASH_VERSION_OVERRIDE=invalid scripts/release_version.sh >/dev/null 2>&1; then
  echo 'release version script accepted an invalid override' >&2
  exit 1
fi
if cmake -S "$root" -B "$tmp/invalid-override" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$root/cmake/toolchains/lonehash-cross.cmake" \
  -DLONEHASH_TARGET_ID=x86_64-linux-gnu \
  -DLONEHASH_VERSION_OVERRIDE=invalid >/dev/null 2>&1; then
  echo 'CMake accepted an invalid release version override' >&2
  exit 1
fi
if git tag --points-at HEAD --list 'v[0-9]*.[0-9]*.[0-9]*' | grep . >/dev/null; then
  exit 0
fi

tag=v99.99.99
git tag -d "$tag" >/dev/null 2>&1 || true
git tag -d v99.99.99-local >/dev/null 2>&1 || true
git tag v99.99.99-local
test "$(scripts/release_version.sh)" = 0.0.0
test "$(make --silent print-release-version)" = 0.0.0
assert_cmake_version "$tmp/untagged" 0.0.0
git tag -d v99.99.99-local >/dev/null
git tag "$tag"
test "$(scripts/release_version.sh)" = 99.99.99
test "$(make --silent print-release-version)" = 99.99.99
assert_cmake_version "$tmp/tagged" 99.99.99
