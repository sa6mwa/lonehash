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
  "lonehash-$version-1.rockspec" \
  include/lonehash/lonehash.h \
  lua/lonehash.lua \
  lua/lh.lua \
  lua/lonehash/core.c \
  lua/examples/hash_strings.lua \
  lua/examples/hash_file.lua; do
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
lonehash-$version-1.rockspec
include/lonehash/lonehash.h
lua/lonehash.lua
lua/lh.lua
lua/lonehash/core.c
lua/examples/hash_strings.lua
lua/examples/hash_file.lua
EOF
