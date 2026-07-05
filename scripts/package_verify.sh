#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
dist="${LONEHASH_DIST_DIR:-$root/dist}"
manifest="$dist/lonehash-$version-CHECKSUMS"
tmp="$root/.cache/package-verify"

if [ ! -f "$manifest" ]; then
  echo "missing checksum manifest: $manifest" >&2
  exit 1
fi

(cd "$dist" && sha256sum -c "$(basename "$manifest")")

rm -rf "$tmp"
mkdir -p "$tmp"

while read -r _hash artifact; do
  case "$artifact" in
    lonehash-"$version".tar.gz)
      tar -C "$tmp" -xzf "$dist/$artifact"
      test -f "$tmp/lonehash-$version/CMakeLists.txt"
      test -f "$tmp/lonehash-$version/VERSION"
      ;;
    lonehash-"$version"-*.tar.gz)
      root_name=${artifact%.tar.gz}
      tar -C "$tmp" -xzf "$dist/$artifact"
      test -f "$tmp/$root_name/include/lonehash/lonehash.h"
      test -f "$tmp/$root_name/lib/pkgconfig/lonehash.pc"
      test -f "$tmp/$root_name/lib/cmake/lonehash/lonehashConfig.cmake"
      test -f "$tmp/$root_name/share/doc/lonehash/LICENSE"
      ;;
  esac
done <"$manifest"

if grep -R "$root" "$tmp" "$manifest" >/dev/null 2>&1; then
  echo "release artifact leaks repository path" >&2
  exit 1
fi

if [ "${HOME:-}" != "" ] && grep -R "$HOME" "$tmp" "$manifest" >/dev/null 2>&1; then
  echo "release artifact leaks HOME path" >&2
  exit 1
fi
