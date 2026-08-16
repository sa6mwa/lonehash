#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'usage: %s <dist-dir> <version>\n' "$0" >&2
  exit 2
fi

dist=$1
version=$2
rockspec="$dist/lonehash-$version-1.rockspec"
source_rock="$dist/lonehash-$version-1.src.rock"
source_archive="$dist/lonehash-lua-$version.tar.gz"

for artifact in "$rockspec" "$source_rock" "$source_archive"; do
  test -f "$artifact" || { echo "missing Lua artifact: $artifact" >&2; exit 1; }
done
grep -F "version = \"$version-1\"" "$rockspec" >/dev/null
grep -F "url = \"lonehash-lua-$version.tar.gz\"" "$rockspec" >/dev/null
! grep -E 'file://|/home/|/tmp/|/build/|/.cache/' "$rockspec" >/dev/null

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
unzip -q "$source_rock" -d "$tmp"
cmp "$rockspec" "$tmp/lonehash-$version-1.rockspec"
cmp "$source_archive" "$tmp/lonehash-lua-$version.tar.gz"
mkdir -p "$tmp/source"
tar -C "$tmp/source" -xzf "$source_archive"
stage="$tmp/source/lonehash-lua-$version"
test "$(sed -n '1p' "$stage/VERSION")" = "$version"
cmp "$rockspec" "$stage/lonehash-$version-1.rockspec"
for file in \
  RELEASE_MANIFEST lonehash.rockspec.in \
  scripts/build_lua_rock.sh scripts/render_release_rockspec.sh \
  scripts/stage_lua_rock_sources.sh scripts/release_version.sh \
  lua/lonehash.lua lua/lonehash/core.c include/lonehash/lonehash.h; do
  test -f "$stage/$file" || { echo "missing standalone Lua source: $file" >&2; exit 1; }
done
! grep -a -E 'file://|/home/|/tmp/|/build/|/.cache/' "$source_archive" >/dev/null
! grep -a -E 'file://|/home/|/tmp/|/build/|/.cache/' "$source_rock" >/dev/null

if [[ -n "${LONEHASH_PREFIX:-}" ]]; then
  (cd "$stage" && LONEHASH_PREFIX="$LONEHASH_PREFIX" ./scripts/build_lua_rock.sh test)
fi
