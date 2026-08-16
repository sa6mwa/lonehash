#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
dist="${LONEHASH_DIST_DIR:-$root/dist}"
mkdir -p "$dist"
dist=$(CDPATH= cd -- "$dist" && pwd)
manifest="$dist/lonehash-$version-CHECKSUMS"

cd "$dist"
rm -f "$manifest"
if [ -n "${LONEHASH_RELEASE_ASSETS_FILE:-}" ]; then
  test -f "$LONEHASH_RELEASE_ASSETS_FILE" || {
    echo "release asset list is missing: $LONEHASH_RELEASE_ASSETS_FILE" >&2
    exit 1
  }
  while IFS= read -r artifact; do
    case "$artifact" in
      ""|*/*|.*|*..*)
        echo "invalid release asset: $artifact" >&2
        exit 1
        ;;
      lonehash-"$version"*.tar.gz|lonehash-lua-"$version".tar.gz|\
      lonehash-"$version"-1.rockspec|lonehash-"$version"-1.src.rock|\
      lh-"$version"*.tar.gz) ;;
      *)
        echo "invalid release asset: $artifact" >&2
        exit 1
        ;;
    esac
    test -f "$artifact" || {
      echo "release asset is missing: $artifact" >&2
      exit 1
    }
    sha256sum "$artifact" >>"$manifest"
  done <"$LONEHASH_RELEASE_ASSETS_FILE"
else
  for artifact in lonehash-"$version"*.tar.gz lonehash-lua-"$version".tar.gz \
    lonehash-"$version"-1.rockspec lonehash-"$version"-1.src.rock \
    lh-"$version"*.tar.gz; do
    [ -f "$artifact" ] || continue
    sha256sum "$artifact" >>"$manifest"
  done
fi
