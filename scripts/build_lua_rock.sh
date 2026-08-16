#!/usr/bin/env bash
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
build="$root/build/release"
prefix="$root/build/lua-sdk"
tree="$root/build/luarocks"

require_lua55() {
  command -v lua >/dev/null 2>&1 || { echo "Lua 5.5.0 is required" >&2; exit 1; }
  test "$(lua -v 2>&1 | sed -n 's/^Lua \([0-9][^ ]*\).*/\1/p')" = "5.5.0" || {
    echo "Lua 5.5.0 is required" >&2
    exit 1
  }
  command -v luarocks >/dev/null 2>&1 || { echo "LuaRocks for Lua 5.5.0 is required" >&2; exit 1; }
}

build_rock() {
  local version
  require_lua55
  version=$("$root/scripts/release_version.sh")
  rockspec="$root/build/lonehash-$version-1.rockspec"
  cmake --install "$build" --prefix "$prefix"
  sed \
    -e "s/@LONEHASH_LUA_VERSION@/$version/g" \
    -e "s/@LONEHASH_LUA_ROCK_VERSION@/$version/g" \
    "$root/lonehash.rockspec.in" >"$rockspec"
  sed -i \
    -e "s#incdirs = { \"include\" }#incdirs = { \"$prefix/include\" }#" \
    -e "s#libraries = { \"lonehash\" }#libraries = { \"lonehash\" }, libdirs = { \"$prefix/lib\" }#" \
    "$rockspec"
  PKG_CONFIG_PATH="$prefix/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" \
    luarocks --lua-version=5.5 --tree="$tree" make --deps-mode=none "$rockspec" \
      LONEHASH_INCDIR="$prefix/include" LONEHASH_LIBDIR="$prefix/lib"
}

case "${1:-build}" in
  build) build_rock ;;
  env)
    printf 'export LUA_PATH=%q\n' "$tree/share/lua/5.5/?.lua;$tree/share/lua/5.5/?/init.lua;;"
    printf 'export LUA_CPATH=%q\n' "$tree/lib/lua/5.5/?.so;;"
    printf 'export LD_LIBRARY_PATH=%q\n' "$prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ;;
  test)
    build_rock
    eval "$("$0" env)"
    lua "$root/lua/examples/hash_strings.lua"
    printf abc | lua "$root/lua/lh.lua" -sq
    ;;
  *) echo "usage: $0 [build|env|test]" >&2; exit 2 ;;
esac
