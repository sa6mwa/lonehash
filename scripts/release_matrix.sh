#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
toolchains="$root/scripts/cpkt-toolchains.sh"
targets=$("$toolchains" targets)

for target in $targets; do
  preset="$target-release"
  case "$target" in
    arm64-apple-darwin)
      if ! "$toolchains" discover "$target" | grep '^status=ready$' >/dev/null 2>&1; then
        echo "SKIP target=$target reason=darwin-toolchain-unavailable"
        continue
      fi
      ;;
    *)
      "$toolchains" ensure "$target"
      ;;
  esac

  eval "$("$toolchains" env "$target")"
  export LONEHASH_TARGET_ID="$target"
  cmake --preset "$preset"
  cmake --build --preset "$preset"
  "$root/scripts/package.sh" "$target" "$preset"
  "$root/scripts/package_cli.sh" "$target" "$preset"
done
