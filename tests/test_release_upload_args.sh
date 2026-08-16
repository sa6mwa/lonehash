#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
dist="$root/.cache/release-upload-assets"
rm -rf "$dist"
trap 'rm -rf "$dist"' EXIT HUP INT TERM
mkdir -p "$dist"
printf artifact >"$dist/lonehash-0.0.0.tar.gz"
(cd "$dist" && sha256sum lonehash-0.0.0.tar.gz >lonehash-0.0.0-CHECKSUMS)
assets=$(LONEHASH_DIST_DIR="$dist" "$root/scripts/release_upload_args.sh")
test "$(printf '%s\n' "$assets" | wc -l)" = 2
printf '%s\n' "$assets" | grep -Fx "$dist/lonehash-0.0.0-CHECKSUMS" >/dev/null
printf '%s\n' "$assets" | grep -Fx "$dist/lonehash-0.0.0.tar.gz" >/dev/null
printf '%s  ../outside\n' deadbeef >>"$dist/lonehash-0.0.0-CHECKSUMS"
if LONEHASH_DIST_DIR="$dist" "$root/scripts/release_upload_args.sh" >/dev/null 2>&1; then
  echo 'release upload selection accepted a traversal artifact name' >&2
  exit 1
fi
