#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
toolchains="$root/scripts/cpkt-toolchains.sh"
targets=$("$toolchains" targets)
version=$("$root/scripts/release_version.sh")
assets="$root/.cache/release-matrix-assets"

rm -f "$assets"
mkdir -p "$(dirname "$assets")"
: >"$assets"

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
  cmake --preset "$preset"
  cmake --build --preset "$preset"
  if [ "$target" = "x86_64-linux-gnu" ]; then
    ctest --test-dir "$root/build/$preset" --output-on-failure
  fi
  "$root/scripts/package.sh" "$target" "$preset"
  "$root/scripts/package_cli.sh" "$target" "$preset"
  printf '%s\n' "lonehash-$version-$target.tar.gz" "lh-$version-$target.tar.gz" >>"$assets"
done

"$root/scripts/package_source.sh"
printf '%s\n' "lonehash-$version.tar.gz" >>"$assets"
"$root/scripts/package_lua.sh"
printf '%s\n' "lonehash-lua-$version.tar.gz" "lonehash-$version-1.rockspec" \
  "lonehash-$version-1.src.rock" >>"$assets"
LONEHASH_RELEASE_ASSETS_FILE="$assets" "$root/scripts/package_checksums.sh"
"$root/scripts/package_verify.sh"
