#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
tmp="$root/.cache/package-checksums-assets-test"
dist="$tmp/dist"
assets="$tmp/assets"

rm -rf "$tmp"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$dist"
printf current >"$dist/lonehash-0.0.0-x86_64-linux-gnu.tar.gz"
printf stale >"$dist/lonehash-0.0.0-arm64-apple-darwin.tar.gz"
printf 'lonehash-0.0.0-x86_64-linux-gnu.tar.gz\n' >"$assets"
LONEHASH_DIST_DIR="$dist" LONEHASH_RELEASE_ASSETS_FILE="$assets" \
  "$root/scripts/package_checksums.sh"
grep -F 'lonehash-0.0.0-x86_64-linux-gnu.tar.gz' \
  "$dist/lonehash-0.0.0-CHECKSUMS" >/dev/null
if grep -F 'lonehash-0.0.0-arm64-apple-darwin.tar.gz' \
  "$dist/lonehash-0.0.0-CHECKSUMS" >/dev/null; then
  echo 'checksum manifest included a stale matrix artifact' >&2
  exit 1
fi
