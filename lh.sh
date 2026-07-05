#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
lua_bin=${LUA:-lua}

cmake --preset debug >/dev/null
cmake --build --preset debug >/dev/null

export LUA_PATH="$root/lua/?.lua;$root/lua/?/init.lua;;"
export LUA_CPATH="$root/build/debug/?.so;$root/build/debug/?/core.so;;"
export LD_LIBRARY_PATH="$root/build/debug${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export DYLD_LIBRARY_PATH="$root/build/debug${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"

exec "$lua_bin" "$root/lua/lh.lua" "$@"
