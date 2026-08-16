#!/usr/bin/env bash
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
dist=${LONEHASH_DIST_DIR:-$root/dist}
manifest="$dist/lonehash-$version-CHECKSUMS"
test -f "$manifest" || { echo "missing checksum manifest: $manifest" >&2; exit 1; }

printf '%s\n' "$manifest"
while read -r _hash artifact; do
  case "$artifact" in
    ""|*/*|.*|*..*)
      echo "unsafe checksum manifest artifact name: $artifact" >&2
      exit 1
      ;;
  esac
  test -f "$dist/$artifact" || { echo "checksum-listed artifact is missing: $artifact" >&2; exit 1; }
  printf '%s\n' "$dist/$artifact"
done <"$manifest"
