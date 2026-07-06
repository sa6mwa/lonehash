#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
major=$(printf '%s\n' "$version" | cut -d. -f1)
minor=$(printf '%s\n' "$version" | cut -d. -f2)
patch=$(printf '%s\n' "$version" | cut -d. -f3)
dist="${LONEHASH_DIST_DIR:-$root/dist}"
stage_root="$root/.cache/lua-source"
stage="$stage_root/lonehash-lua-$version"
rock_stage="$root/.cache/lua-rock"
rockspec="$dist/lonehash-$version-1.rockspec"
source_archive="lonehash-lua-$version.tar.gz"
source_rock="lonehash-$version-1.src.rock"

rm -rf "$stage_root" "$rock_stage"
mkdir -p "$stage/lua/lonehash" "$stage/lua/examples" \
  "$stage/include/lonehash" "$dist" "$rock_stage"

cp "$root/LICENSE" "$stage/LICENSE"
cp "$root/README.md" "$stage/README.md"
cp "$root/lua/lonehash.lua" "$stage/lua/lonehash.lua"
cp "$root/lua/lh.lua" "$stage/lua/lh.lua"
cp "$root/lua/lonehash/core.c" "$stage/lua/lonehash/core.c"
cp "$root/lua/examples/hash_strings.lua" "$stage/lua/examples/hash_strings.lua"
cp "$root/lua/examples/hash_file.lua" "$stage/lua/examples/hash_file.lua"
printf '%s\n' "$version" >"$stage/VERSION"

sed \
  -e "s/@LONEHASH_VERSION_MAJOR@/$major/g" \
  -e "s/@LONEHASH_VERSION_MINOR@/$minor/g" \
  -e "s/@LONEHASH_VERSION_PATCH@/$patch/g" \
  -e "s/@LONEHASH_VERSION@/$version/g" \
  "$root/include/lonehash/lonehash.h.in" >"$stage/include/lonehash/lonehash.h"

sed \
  -e "s/@LONEHASH_LUA_VERSION@/$version/g" \
  -e "s/@LONEHASH_LUA_ROCK_VERSION@/$version/g" \
  "$root/lonehash.rockspec.in" >"$stage/lonehash-$version-1.rockspec"
cp "$stage/lonehash-$version-1.rockspec" "$rockspec"

cat >"$stage/RELEASE_MANIFEST" <<EOF
LICENSE
README.md
VERSION
RELEASE_MANIFEST
lonehash-$version-1.rockspec
include/lonehash/lonehash.h
lua/lonehash.lua
lua/lh.lua
lua/lonehash/core.c
lua/examples/hash_strings.lua
lua/examples/hash_file.lua
EOF

tar -C "$stage_root" -czf "$dist/$source_archive" "lonehash-lua-$version"

cp "$rockspec" "$rock_stage/"
cp "$dist/$source_archive" "$rock_stage/"
(cd "$rock_stage" && zip -q "$dist/$source_rock" "$(basename "$rockspec")" "$source_archive")
