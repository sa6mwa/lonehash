#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
cd "$root"
tmp="$root/.cache/release-version-test"
rm -rf "$tmp"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

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
mkdir -p "$tmp/nested-source/scripts"
cp "$root/scripts/release_version.sh" "$tmp/nested-source/scripts/"
printf '6.7.8\n' >"$tmp/nested-source/VERSION"
test "$("$tmp/nested-source/scripts/release_version.sh")" = 6.7.8
mkdir -p "$tmp/tagged-source/scripts"
cp "$root/scripts/release_version.sh" "$tmp/tagged-source/scripts/"
printf '99.99.99\n' >"$tmp/tagged-source/VERSION"
git -C "$tmp/tagged-source" init -q
git -C "$tmp/tagged-source" config user.email lifecycle@example.invalid
git -C "$tmp/tagged-source" config user.name lifecycle-test
git -C "$tmp/tagged-source" add VERSION scripts/release_version.sh
git -C "$tmp/tagged-source" commit -qm 'test release version'
git -C "$tmp/tagged-source" tag v99.99.99
test "$("$tmp/tagged-source/scripts/release_version.sh")" = 99.99.99
printf 'dirty\n' >>"$tmp/tagged-source/VERSION"
if "$tmp/tagged-source/scripts/release_version.sh" >"$tmp/dirty-version.out" \
  2>"$tmp/dirty-version.err"; then
  echo 'release version script accepted a dirty tagged worktree' >&2
  exit 1
fi
grep 'requires a clean worktree' "$tmp/dirty-version.err" >/dev/null
git -C "$tmp/tagged-source" checkout -- VERSION
printf untracked >"$tmp/tagged-source/untracked"
if "$tmp/tagged-source/scripts/release_version.sh" >"$tmp/untracked-version.out" \
  2>"$tmp/untracked-version.err"; then
  echo 'release version script accepted an untracked file in a tagged worktree' >&2
  exit 1
fi
grep 'requires a clean worktree' "$tmp/untracked-version.err" >/dev/null
