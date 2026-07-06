#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
dist="${LONEHASH_DIST_DIR:-$root/dist}"
tmp="$root/.cache/source-smoke"

rm -rf "$tmp"
mkdir -p "$tmp"
tar -C "$tmp" -xzf "$dist/lonehash-$version.tar.gz"
test "$(sed -n '1p' "$tmp/lonehash-$version/VERSION")" = "$version"
cmake -S "$tmp/lonehash-$version" -B "$tmp/build" -G Ninja
grep "#define LONEHASH_VERSION \"$version\"" \
  "$tmp/build/generated/include/lonehash/lonehash.h" >/dev/null
grep "Version: $version" "$tmp/build/lonehash.pc" >/dev/null
cmake --build "$tmp/build"
ctest --test-dir "$tmp/build" --output-on-failure
