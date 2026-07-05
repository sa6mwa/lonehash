#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
dist="${LONEHASH_DIST_DIR:-$root/dist}"
target="${1:-host}"
preset="${2:-release}"
stage="$root/.cache/package/$target/stage"
prefix="$stage/lonehash-$version-$target"

rm -rf "$stage"
mkdir -p "$dist" "$prefix"

cmake --preset "$preset"
cmake --build --preset "$preset"
cmake --install "$root/build/$preset" --prefix "$prefix"

tar -C "$stage" -czf "$dist/lonehash-$version-$target.tar.gz" \
  "lonehash-$version-$target"
