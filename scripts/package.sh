#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
dist="${LONEHASH_DIST_DIR:-$root/dist}"
target="${1:-x86_64-linux-gnu}"
preset="${2:-release}"
stage="$root/.cache/package/$target/stage"
prefix="$stage/lonehash-$version-$target"

rm -rf "$stage"
mkdir -p "$dist" "$prefix"

cmake --preset "$preset"
cmake --build --preset "$preset"
cmake --install "$root/build/$preset" --prefix "$prefix"
eval "$("$root/scripts/discover_target_tools.sh" "$root/build/$preset" "$target")"
case "$target" in
  *apple-darwin) ;;
  *)
    "$STRIP" -g "$prefix/lib/liblonehash.a"
    find "$prefix/lib" -type f -name 'liblonehash.so*' -exec "$STRIP" --strip-unneeded {} \;
    ;;
esac

tar -C "$stage" -czf "$dist/lonehash-$version-$target.tar.gz" \
  "lonehash-$version-$target"
