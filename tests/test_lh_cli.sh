#!/bin/sh
set -eu

lh=$1
tmp=${TMPDIR:-/tmp}/lonehash-cli-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

printf abc >"$tmp/abc.txt"

sha=$("$lh" --sha256 "$tmp/abc.txt")
test "$sha" = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  $tmp/abc.txt"

md5=$("$lh" --md5 "$tmp/abc.txt")
test "$md5" = "900150983cd24fb0d6963f7d28e17f72  $tmp/abc.txt"

stdin_sha=$(printf abc | "$lh" -s)
test "$stdin_sha" = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  -"

printf abc | "$lh" -5 -z >"$tmp/nul.out"
bytes=$(wc -c <"$tmp/nul.out" | tr -d ' ')
test "$bytes" = "36"
tail_byte=$(od -An -tx1 -N1 -j35 "$tmp/nul.out" | tr -d ' \n')
test "$tail_byte" = "00"

printf abc | "$lh" -5z >"$tmp/cluster.out"
cluster_bytes=$(wc -c <"$tmp/cluster.out" | tr -d ' ')
test "$cluster_bytes" = "36"
cluster_prefix=$(LC_ALL=C tr '\000' '\n' <"$tmp/cluster.out")
test "$cluster_prefix" = "900150983cd24fb0d6963f7d28e17f72  -"

cluster_sha=$(printf abc | "$lh" -5zs)
test "$cluster_sha" = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  -"

printf abc | "$lh" -szq >"$tmp/quiet-raw.out"
quiet_raw_bytes=$(wc -c <"$tmp/quiet-raw.out" | tr -d ' ')
test "$quiet_raw_bytes" = "65"
quiet_raw_tail=$(od -An -tx1 -N1 -j64 "$tmp/quiet-raw.out" | tr -d ' \n')
test "$quiet_raw_tail" = "00"

for opts in -szq -zqs -qsz; do
  printf abc | "$lh" "$opts" >"$tmp/quiet-cluster.out"
  quiet_cluster_bytes=$(wc -c <"$tmp/quiet-cluster.out" | tr -d ' ')
  test "$quiet_cluster_bytes" = "65"
  quiet_cluster_tail=$(od -An -tx1 -N1 -j64 "$tmp/quiet-cluster.out" | tr -d ' \n')
  test "$quiet_cluster_tail" = "00"
done

quiet_file=$("$lh" --md5 --quiet "$tmp/abc.txt")
test "$quiet_file" = "900150983cd24fb0d6963f7d28e17f72"

if "$lh" --quiet "$tmp/abc.txt" >/dev/full 2>"$tmp/write-error.err"; then
  echo 'CLI accepted a stdout write failure' >&2
  exit 1
fi
grep 'stdout: write failed' "$tmp/write-error.err" >/dev/null

if "$lh" --quiet "$tmp/abc.txt" "$tmp/abc.txt" >"$tmp/quiet-many.out" 2>"$tmp/quiet-many.err"; then
  exit 1
fi
grep "requires stdin or exactly one FILE" "$tmp/quiet-many.err" >/dev/null
