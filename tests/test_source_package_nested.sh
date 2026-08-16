#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
tmp="$root/.cache/source-package-nested-test"
source_root="$tmp/nested-source"

rm -rf "$tmp"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$source_root/scripts"
cp "$root/scripts/package_source.sh" "$source_root/scripts/"
cp "$root/scripts/release_version.sh" "$source_root/scripts/"
printf '1.2.3\n' >"$source_root/VERSION"
cat >"$source_root/RELEASE_MANIFEST" <<'EOF'
VERSION
RELEASE_MANIFEST
scripts/package_source.sh
scripts/release_version.sh
EOF

LONEHASH_DIST_DIR="$tmp/dist" "$source_root/scripts/package_source.sh"
tar -tzf "$tmp/dist/lonehash-1.2.3.tar.gz" | grep -Fx \
  'lonehash-1.2.3/scripts/package_source.sh' >/dev/null
