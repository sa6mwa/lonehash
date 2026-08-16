#!/usr/bin/env bash
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
output=${1:-"${LONEHASH_DIST_DIR:-$root/dist}/lonehash-$version-1.rockspec"}
mkdir -p "$(dirname "$output")"
sed \
  -e "s/@LONEHASH_LUA_VERSION@/$version/g" \
  -e "s/@LONEHASH_LUA_ROCK_VERSION@/$version/g" \
  "$root/lonehash.rockspec.in" >"$output"
