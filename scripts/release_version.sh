#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

is_semver() {
  printf '%s\n' "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'
}

if [ "${LONEHASH_VERSION_OVERRIDE:-}" != "" ]; then
  if ! is_semver "$LONEHASH_VERSION_OVERRIDE"; then
    echo "LONEHASH_VERSION_OVERRIDE must be a semver version (X.Y.Z)" >&2
    exit 2
  fi
  printf '%s\n' "$LONEHASH_VERSION_OVERRIDE"
  exit 0
fi

if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  for tag in $(git -C "$root" tag --points-at HEAD --list); do
    if is_semver "${tag#v}" && [ "${tag#v}" != "$tag" ] \
      && [ "$(git -C "$root" cat-file -t "refs/tags/$tag")" = commit ]; then
      printf '%s\n' "${tag#v}"
      exit 0
    fi
  done
  printf '0.0.0\n'
  exit 0
fi

if [ -f "$root/VERSION" ]; then
  version=$(sed -n '1p' "$root/VERSION")
  if ! is_semver "$version"; then
    echo "source archive VERSION must be a semver version (X.Y.Z)" >&2
    exit 2
  fi
  printf '%s\n' "$version"
  exit 0
fi

printf '0.0.0\n'
