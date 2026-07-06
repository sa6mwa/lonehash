#!/bin/sh
set -eu

root=$1
build=$2
lua_bin=${LUA:-lua}

export LUA_PATH="$root/lua/?.lua;$root/lua/?/init.lua;;"
export LUA_CPATH="$build/?.so;$build/?/core.so;;"
export LD_LIBRARY_PATH="$build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export DYLD_LIBRARY_PATH="$build${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"

sha=$("$lua_bin" -e 'local h=require("lonehash"); io.write(h.sha256_hex("abc"))')
test "$sha" = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

md5=$("$lua_bin" -e 'local h=require("lonehash"); io.write(h.md5_hex("abc"))')
test "$md5" = "900150983cd24fb0d6963f7d28e17f72"

stream=$("$lua_bin" -e 'local h=require("lonehash").sha256(); h:update("a"):update("b"):update("c"); io.write(h:final_hex())')
test "$stream" = "$sha"

tmp="$build/lua-test-input.txt"
printf abc >"$tmp"
file_sha=$("$lua_bin" "$root/lua/examples/hash_file.lua" "$tmp")
test "$file_sha" = "$sha"

cli_sha=$(printf abc | "$build/lh.sh" -sq)
test "$cli_sha" = "$sha"
