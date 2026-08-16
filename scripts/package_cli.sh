#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
dist="${LONEHASH_DIST_DIR:-$root/dist}"
target="${1:-x86_64-linux-gnu}"
preset="${2:-release}"
stage="$root/.cache/package-cli/$target/stage"
prefix="$stage/lh-$version-$target"

rm -rf "$stage"
mkdir -p "$dist" "$prefix/bin" "$prefix/share/doc/lonehash"

cmake --preset "$preset"
cmake --build --preset "$preset" --target lh
eval "$("$root/scripts/discover_target_tools.sh" "$root/build/$preset" "$target")"

cp "$root/build/$preset/lh" "$prefix/bin/lh"
case "$target" in
  *apple-darwin) ;;
  *)
    "$STRIP" "$prefix/bin/lh"
    ;;
esac
cp "$root/README.md" "$prefix/share/doc/lonehash/README.md"
cp "$root/LICENSE" "$prefix/share/doc/lonehash/LICENSE"

tar -C "$stage" -czf "$dist/lh-$version-$target.tar.gz" \
  "lh-$version-$target"
