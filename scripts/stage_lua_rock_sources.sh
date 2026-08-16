#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <staging-directory>" >&2
  exit 64
fi

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
stage=$1

for file in \
  LICENSE \
  README.md \
  VERSION \
  lonehash.rockspec.in \
  "lonehash-$version-1.rockspec" \
  include/lonehash/lonehash.h \
  include/lonehash/lonehash_version.h \
  lua/lonehash.lua \
  lua/lh.lua \
  lua/lonehash/core.c \
  lua/examples/hash_strings.lua \
  lua/examples/hash_file.lua \
  scripts/build_lua_rock.sh \
  scripts/render_release_rockspec.sh \
  scripts/stage_lua_rock_sources.sh \
  scripts/release_version.sh; do
  if [ ! -f "$stage/$file" ]; then
    echo "missing Lua release source: $stage/$file" >&2
    exit 1
  fi
done

cat >"$stage/RELEASE_MANIFEST" <<EOF
LICENSE
README.md
VERSION
RELEASE_MANIFEST
lonehash.rockspec.in
lonehash-$version-1.rockspec
include/lonehash/lonehash.h
include/lonehash/lonehash_version.h
lua/lonehash.lua
lua/lh.lua
lua/lonehash/core.c
lua/examples/hash_strings.lua
lua/examples/hash_file.lua
scripts/build_lua_rock.sh
scripts/render_release_rockspec.sh
scripts/stage_lua_rock_sources.sh
scripts/release_version.sh
EOF
