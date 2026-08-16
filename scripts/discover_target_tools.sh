#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'usage: %s <configured-build-dir> <target-id>\n' "$0" >&2
  exit 2
fi

build_dir=$1
target_id=$2
cache="$build_dir/CMakeCache.txt"
[[ -f "$cache" ]] || {
  printf 'configured CMake cache is required: %s\n' "$cache" >&2
  exit 1
}

cache_value() {
  local key=$1
  sed -n "s#^${key}:[^=]*=##p" "$cache" | sed -n '1p'
}

require_value() {
  local key=$1 value
  value=$(cache_value "$key")
  [[ -n "$value" && -x "$value" ]] || {
    printf 'configured %s is unavailable for %s: %s\n' "$key" "$target_id" "$value" >&2
    exit 1
  }
  printf '%s\n' "$value"
}

cc=$(require_value CMAKE_C_COMPILER)
strip=$(require_value CMAKE_STRIP)
printf 'CC=%q\n' "$cc"
printf 'STRIP=%q\n' "$strip"

if [[ "$target_id" == *apple-darwin ]]; then
  otool=$(require_value CMAKE_OTOOL)
  install_name_tool=$(require_value CMAKE_INSTALL_NAME_TOOL)
  printf 'OTOOL=%q\n' "$otool"
  printf 'INSTALL_NAME_TOOL=%q\n' "$install_name_tool"
else
  readelf=$(require_value CMAKE_READELF)
  printf 'READELF=%q\n' "$readelf"
fi
