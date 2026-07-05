#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
dist="${LONEHASH_DIST_DIR:-$root/dist}"
manifest="$dist/lonehash-$version-CHECKSUMS"

cd "$dist"
rm -f "$manifest"
for artifact in lonehash-"$version"*.tar.gz lonehash-lua-"$version".tar.gz \
  lonehash-"$version"-1.rockspec lonehash-"$version"-1.src.rock \
  lh-"$version"*.tar.gz; do
  [ -f "$artifact" ] || continue
  sha256sum "$artifact" >>"$manifest"
done
