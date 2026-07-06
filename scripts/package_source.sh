#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
version=$("$root/scripts/release_version.sh")
dist="${LONEHASH_DIST_DIR:-$root/dist}"
stage="$root/.cache/source/lonehash-$version"

rm -rf "$stage"
mkdir -p "$stage" "$dist"

if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$root" ls-files --cached >"$root/.cache/source-manifest"
else
  if [ ! -f "$root/RELEASE_MANIFEST" ]; then
    echo "RELEASE_MANIFEST is required outside a git worktree" >&2
    exit 1
  fi
  cp "$root/RELEASE_MANIFEST" "$root/.cache/source-manifest"
fi

while IFS= read -r file; do
  case "$file" in
    dist/*|build/*|.cache/*) continue ;;
  esac
  mkdir -p "$stage/$(dirname "$file")"
  cp "$root/$file" "$stage/$file"
done <"$root/.cache/source-manifest"

printf '%s\n' "$version" >"$stage/VERSION"
cp "$root/.cache/source-manifest" "$stage/RELEASE_MANIFEST"
tar -C "$root/.cache/source" -czf "$dist/lonehash-$version.tar.gz" \
  "lonehash-$version"
