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

require_no_local_paths() {
  if grep -a -E 'file://|/home/|/tmp/|/build/|/.cache/' "$1" >/dev/null; then
    echo "forbidden local path in Lua artifact: $1" >&2
    exit 1
  fi
}

for artifact in "$rockspec" "$source_rock" "$source_archive"; do
  test -f "$artifact" || { echo "missing Lua artifact: $artifact" >&2; exit 1; }
done
grep -F "version = \"$version-1\"" "$rockspec" >/dev/null
grep -F "url = \"lonehash-lua-$version.tar.gz\"" "$rockspec" >/dev/null
require_no_local_paths "$rockspec"

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
require_no_local_paths "$source_archive"
require_no_local_paths "$source_rock"

if [[ -n "${LONEHASH_PREFIX:-}" ]]; then
  (cd "$stage" && LONEHASH_PREFIX="$LONEHASH_PREFIX" ./scripts/build_lua_rock.sh test)
fi
