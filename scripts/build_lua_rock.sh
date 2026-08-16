#!/usr/bin/env bash
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
build="$root/build/release"
prefix="$root/build/lua-sdk"
tree="$root/build/luarocks"
sdk_include=
sdk_lib=

require_lua55() {
  command -v lua >/dev/null 2>&1 || { echo "Lua 5.5.0 is required" >&2; exit 1; }
  test "$(lua -v 2>&1 | sed -n 's/^Lua \([0-9][^ ]*\).*/\1/p')" = "5.5.0" || {
    echo "Lua 5.5.0 is required" >&2
    exit 1
  }
  command -v luarocks >/dev/null 2>&1 || { echo "LuaRocks for Lua 5.5.0 is required" >&2; exit 1; }
}

discover_sdk() {
  if [[ -f "$root/CMakeLists.txt" ]]; then
    cmake --install "$build" --prefix "$prefix" >&2
    sdk_include="$prefix/include"
    sdk_lib="$prefix/lib"
    return
  fi

  if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists lonehash; then
    sdk_include=$(pkg-config --variable=includedir lonehash)
    sdk_lib=$(pkg-config --variable=libdir lonehash)
  elif [[ -n "${LONEHASH_PREFIX:-}" ]]; then
    sdk_include="$LONEHASH_PREFIX/include"
    if [[ -d "$LONEHASH_PREFIX/lib" ]]; then
      sdk_lib="$LONEHASH_PREFIX/lib"
    else
      sdk_lib="$LONEHASH_PREFIX/lib64"
    fi
  else
    echo "liblonehash SDK not found: install its pkg-config metadata or set LONEHASH_PREFIX" >&2
    exit 1
  fi

  [[ -f "$sdk_include/lonehash/lonehash.h" && -d "$sdk_lib" ]] || {
    echo "invalid liblonehash SDK: include=$sdk_include lib=$sdk_lib" >&2
    exit 1
  }
}

build_rock() {
  local version rockspec
  require_lua55
  discover_sdk
  version=$("$root/scripts/release_version.sh")
  mkdir -p "$root/build"
  rockspec="$root/build/lonehash-$version-1.rockspec"
  sed \
    -e "s/@LONEHASH_LUA_VERSION@/$version/g" \
    -e "s/@LONEHASH_LUA_ROCK_VERSION@/$version/g" \
    "$root/lonehash.rockspec.in" >"$rockspec"
  sed -i \
    -e "s#incdirs = { \"include\" }#incdirs = { \"$sdk_include\" }#" \
    -e "s#libraries = { \"lonehash\" }#libraries = { \"lonehash\" }, libdirs = { \"$sdk_lib\" }#" \
    "$rockspec"
  PKG_CONFIG_PATH="$sdk_lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" \
    luarocks --lua-version=5.5 --tree="$tree" make --deps-mode=none "$rockspec" \
      LONEHASH_INCDIR="$sdk_include" LONEHASH_LIBDIR="$sdk_lib"
}

case "${1:-build}" in
  build) build_rock ;;
  env)
    require_lua55
    discover_sdk
    printf 'export LUA_PATH=%q\n' "$tree/share/lua/5.5/?.lua;$tree/share/lua/5.5/?/init.lua;;"
    printf 'export LUA_CPATH=%q\n' "$tree/lib/lua/5.5/?.so;;"
    printf 'export LD_LIBRARY_PATH=%q\n' "$sdk_lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    printf 'export DYLD_LIBRARY_PATH=%q\n' "$sdk_lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
    ;;
  test)
    build_rock
    eval "$("$0" env)"
    lua "$root/lua/examples/hash_strings.lua"
    printf abc | lua "$root/lua/lh.lua" -sq
    ;;
  *) echo "usage: $0 [build|env|test]" >&2; exit 2 ;;
esac
