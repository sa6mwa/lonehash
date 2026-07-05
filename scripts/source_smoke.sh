#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
dist="${LONEHASH_DIST_DIR:-$root/dist}"
tmp="$root/.cache/source-smoke"

rm -rf "$tmp"
mkdir -p "$tmp"
tar -C "$tmp" -xzf "$dist/lonehash-$version.tar.gz"
cmake -S "$tmp/lonehash-$version" -B "$tmp/build" -G Ninja
cmake --build "$tmp/build"
ctest --test-dir "$tmp/build" --output-on-failure
