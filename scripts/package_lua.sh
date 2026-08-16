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
  "$stage/include/lonehash" "$stage/scripts" "$dist" "$rock_stage"

cp "$root/LICENSE" "$stage/LICENSE"
cp "$root/README.md" "$stage/README.md"
cp "$root/lua/lonehash.lua" "$stage/lua/lonehash.lua"
cp "$root/lua/lh.lua" "$stage/lua/lh.lua"
cp "$root/lua/lonehash/core.c" "$stage/lua/lonehash/core.c"
cp "$root/lua/examples/hash_strings.lua" "$stage/lua/examples/hash_strings.lua"
cp "$root/lua/examples/hash_file.lua" "$stage/lua/examples/hash_file.lua"
cp "$root/lonehash.rockspec.in" "$stage/lonehash.rockspec.in"
cp "$root/scripts/build_lua_rock.sh" "$stage/scripts/build_lua_rock.sh"
cp "$root/scripts/render_release_rockspec.sh" "$stage/scripts/render_release_rockspec.sh"
cp "$root/scripts/stage_lua_rock_sources.sh" "$stage/scripts/stage_lua_rock_sources.sh"
cp "$root/scripts/release_version.sh" "$stage/scripts/release_version.sh"
cp "$root/include/lonehash/lonehash.h" "$stage/include/lonehash/lonehash.h"
printf '%s\n' "$version" >"$stage/VERSION"

sed \
  -e "s/@LONEHASH_VERSION_MAJOR@/$major/g" \
  -e "s/@LONEHASH_VERSION_MINOR@/$minor/g" \
  -e "s/@LONEHASH_VERSION_PATCH@/$patch/g" \
  -e "s/@LONEHASH_VERSION@/$version/g" \
  "$root/include/lonehash/lonehash_version.h.in" \
  >"$stage/include/lonehash/lonehash_version.h"

"$root/scripts/render_release_rockspec.sh" "$stage/lonehash-$version-1.rockspec"
cp "$stage/lonehash-$version-1.rockspec" "$rockspec"

"$root/scripts/stage_lua_rock_sources.sh" "$stage"

tar -C "$stage_root" -czf "$dist/$source_archive" "lonehash-lua-$version"

cp "$rockspec" "$rock_stage/"
sed -i "s#url = \"$source_archive\"#url = \"file://$dist/$source_archive\"#" \
  "$rock_stage/$(basename "$rockspec")"
(cd "$rock_stage" && luarocks --lua-version=5.5 pack "$(basename "$rockspec")")
unpack="$rock_stage/unpack"
mkdir -p "$unpack"
unzip -q "$rock_stage/$source_rock" -d "$unpack"
cp "$rockspec" "$unpack/$(basename "$rockspec")"
rm -f "$dist/$source_rock"
(cd "$unpack" && zip -q "$dist/$source_rock" "$(basename "$rockspec")" "$source_archive")
