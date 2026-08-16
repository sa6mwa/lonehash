#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
dist="$root/.cache/lua-artifact-validation"
rm -rf "$dist"
trap 'rm -rf "$dist"' EXIT HUP INT TERM
mkdir -p "$dist"

cat >"$dist/lonehash-0.0.0-1.rockspec" <<'EOF'
version = "0.0.0-1"
source = { url = "file:///home/developer/lonehash-lua-0.0.0.tar.gz" }
EOF
touch "$dist/lonehash-0.0.0-1.src.rock" "$dist/lonehash-lua-0.0.0.tar.gz"

if "$root/scripts/validate_luarocks.sh" "$dist" 0.0.0; then
  echo 'Lua artifact validator accepted a workstation-local source URL' >&2
  exit 1
fi
