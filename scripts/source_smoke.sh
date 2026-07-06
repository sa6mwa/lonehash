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
if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$root" ls-files --cached | sed "s#^#lonehash-$version/#" \
    >"$tmp/expected-manifest"
  printf '%s\n' "lonehash-$version/VERSION" \
    "lonehash-$version/RELEASE_MANIFEST" >>"$tmp/expected-manifest"
  tar -tf "$dist/lonehash-$version.tar.gz" | grep -v '/$' \
    >"$tmp/archive-manifest"
  sort "$tmp/expected-manifest" >"$tmp/expected-manifest.sorted"
  sort "$tmp/archive-manifest" >"$tmp/archive-manifest.sorted"
  diff -u "$tmp/expected-manifest.sorted" "$tmp/archive-manifest.sorted"
fi
cmake -S "$tmp/lonehash-$version" -B "$tmp/build" -G Ninja
grep "#define LONEHASH_VERSION \"$version\"" \
  "$tmp/build/generated/include/lonehash/lonehash.h" >/dev/null
grep "Version: $version" "$tmp/build/lonehash.pc" >/dev/null
cmake --build "$tmp/build"
ctest --test-dir "$tmp/build" --output-on-failure
