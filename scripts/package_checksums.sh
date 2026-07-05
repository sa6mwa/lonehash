#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
dist="${LONEHASH_DIST_DIR:-$root/dist}"
manifest="$dist/lonehash-$version-CHECKSUMS"

cd "$dist"
rm -f "$manifest"
for artifact in lonehash-"$version"*.tar.gz lh-"$version"*.tar.gz; do
  [ -f "$artifact" ] || continue
  sha256sum "$artifact" >>"$manifest"
done
