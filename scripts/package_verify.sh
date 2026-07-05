#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
dist="${LONEHASH_DIST_DIR:-$root/dist}"
manifest="$dist/lonehash-$version-CHECKSUMS"
tmp="$root/.cache/package-verify"

fail() {
  echo "$1" >&2
  exit 1
}

scan_path() {
  artifact=$1
  path=$2
  needle=$3
  label=$4
  if [ "$needle" != "" ] && grep -a -n "$needle" "$path" >/dev/null 2>&1; then
    echo "release artifact leaks $label" >&2
    echo "artifact=$artifact" >&2
    echo "path=$path" >&2
    exit 1
  fi
}

scan_tree() {
  artifact=$1
  dir=$2
  find "$dir" -type f -print | while IFS= read -r file; do
    scan_path "$artifact" "$file" "$root" "repository path"
    scan_path "$artifact" "$file" "${HOME:-}" "HOME path"
    scan_path "$artifact" "$file" "file://$root" "repository file URL"
    if [ "${HOME:-}" != "" ]; then
      scan_path "$artifact" "$file" "file://$HOME" "HOME file URL"
    fi
  done
  find "$dir" -type l -print | while IFS= read -r link; do
    target=$(readlink "$link")
    case "$target" in
      "$root"*|"$HOME"*)
        echo "release symlink leaks local path" >&2
        echo "artifact=$artifact" >&2
        echo "path=$link" >&2
        echo "target=$target" >&2
        exit 1
        ;;
    esac
  done
}

if [ ! -f "$manifest" ]; then
  fail "missing checksum manifest: $manifest"
fi

(cd "$dist" && sha256sum -c "$(basename "$manifest")")

rm -rf "$tmp"
mkdir -p "$tmp"

scan_path "$(basename "$manifest")" "$manifest" "$root" "repository path"
scan_path "$(basename "$manifest")" "$manifest" "${HOME:-}" "HOME path"

while read -r _hash artifact; do
  case "$artifact" in
    lonehash-"$version".tar.gz)
      root_name="lonehash-$version"
      tar -C "$tmp" -xzf "$dist/$artifact"
      test -f "$tmp/$root_name/CMakeLists.txt"
      test -f "$tmp/$root_name/VERSION"
      test -f "$tmp/$root_name/RELEASE_MANIFEST"
      scan_tree "$artifact" "$tmp/$root_name"
      ;;
    lonehash-"$version"-*.tar.gz)
      root_name=${artifact%.tar.gz}
      tar -C "$tmp" -xzf "$dist/$artifact"
      test -f "$tmp/$root_name/include/lonehash/lonehash.h"
      test -f "$tmp/$root_name/lib/pkgconfig/lonehash.pc"
      test -f "$tmp/$root_name/lib/cmake/lonehash/lonehashConfig.cmake"
      test -f "$tmp/$root_name/share/doc/lonehash/LICENSE"
      if [ -e "$tmp/$root_name/bin/lh" ]; then
        fail "library SDK unexpectedly contains lh CLI: $artifact"
      fi
      scan_tree "$artifact" "$tmp/$root_name"
      ;;
    lh-"$version"-*.tar.gz)
      root_name=${artifact%.tar.gz}
      tar -C "$tmp" -xzf "$dist/$artifact"
      test -x "$tmp/$root_name/bin/lh"
      test -f "$tmp/$root_name/share/doc/lonehash/README.md"
      test -f "$tmp/$root_name/share/doc/lonehash/LICENSE"
      if [ -e "$tmp/$root_name/include" ] || [ -e "$tmp/$root_name/lib" ]; then
        fail "lh CLI package contains library SDK directories: $artifact"
      fi
      scan_tree "$artifact" "$tmp/$root_name"
      ;;
    *)
      fail "unexpected checksum artifact: $artifact"
      ;;
  esac
done <"$manifest"
