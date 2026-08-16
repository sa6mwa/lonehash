#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
tmp="$root/.cache/lua-rock-regeneration-test"
dist="$tmp/dist"
fake_bin="$tmp/bin"
version=$("$root/scripts/release_version.sh")
source_rock="$dist/lonehash-$version-1.src.rock"

rm -rf "$tmp"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$dist" "$fake_bin"

cat >"$fake_bin/luarocks" <<'EOF'
#!/bin/sh
set -eu
for rockspec; do :; done
archive=${rockspec%.rockspec}.src.rock
source_archive=$(sed -n 's/.*file:\/\/\(.*\)".*/\1/p' "$rockspec")
zip -qj "$archive" "$rockspec" "$source_archive"
EOF
chmod +x "$fake_bin/luarocks"

PATH="$fake_bin:$PATH" LONEHASH_DIST_DIR="$dist" "$root/scripts/package_lua.sh"
mkdir -p "$tmp/stale"
printf stale >"$tmp/stale/obsolete-file"
(cd "$tmp/stale" && zip -q "$source_rock" obsolete-file)
PATH="$fake_bin:$PATH" LONEHASH_DIST_DIR="$dist" "$root/scripts/package_lua.sh"
if unzip -Z1 "$source_rock" | grep -Fx obsolete-file >/dev/null; then
  echo 'Lua source rock retained an obsolete entry after regeneration' >&2
  exit 1
fi

(cd "$tmp" && PATH="$fake_bin:$PATH" LONEHASH_DIST_DIR=relative-dist \
  "$root/scripts/package_lua.sh")
test -f "$tmp/relative-dist/lonehash-$version-1.rockspec"
test -f "$tmp/relative-dist/lonehash-lua-$version.tar.gz"
test -f "$tmp/relative-dist/lonehash-$version-1.src.rock"
