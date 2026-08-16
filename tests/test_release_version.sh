#!/usr/bin/env bash
set -euo pipefail

root=${1:?repository root is required}
cd "$root"

if git tag --points-at HEAD --list 'v[0-9]*.[0-9]*.[0-9]*' | grep . >/dev/null; then
  exit 0
fi

tag=v99.99.99
git tag -d "$tag" >/dev/null 2>&1 || true
trap 'git tag -d "$tag" >/dev/null 2>&1 || true' EXIT HUP INT TERM
git tag "$tag"
test "$(scripts/release_version.sh)" = 99.99.99
