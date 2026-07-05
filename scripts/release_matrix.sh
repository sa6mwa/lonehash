#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
targets="
x86_64-linux-gnu
x86_64-linux-musl
aarch64-linux-gnu
aarch64-linux-musl
armhf-linux-gnu
armhf-linux-musl
arm64-apple-darwin
"

for target in $targets; do
  preset="$target-release"
  if LONEHASH_TARGET_ID="$target" cmake --preset "$preset"; then
    LONEHASH_TARGET_ID="$target" cmake --build --preset "$preset"
    LONEHASH_TARGET_ID="$target" "$root/scripts/package.sh" "$target" "$preset"
  else
    echo "SKIP target=$target reason=toolchain-unavailable-or-unconfigured"
  fi
done
