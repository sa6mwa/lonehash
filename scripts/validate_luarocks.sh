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
test -f "$tmp/lonehash-lua-$version.tar.gz"
tar -tzf "$tmp/lonehash-lua-$version.tar.gz" | grep -Fx "lonehash-lua-$version/RELEASE_MANIFEST" >/dev/null
! grep -a -E 'file://|/home/|/tmp/|/build/|/.cache/' "$source_rock" >/dev/null
