#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/build/diagnostic-init}"
CLANG="${CLANG:-clang}"

mkdir -p "$OUT"

"$CLANG" \
	--target=x86_64-linux-gnu \
	-nostdlib \
	-static \
	-fuse-ld=lld \
	-Wl,--build-id=none \
	-Wl,-e,_start \
	"$ROOT/boot-test/init.S" \
	-o "$OUT/init"

sed "s|/absolute/path/to/compiled/init|$OUT/init|" \
	"$ROOT/boot-test/initramfs.list.example" \
	> "$OUT/initramfs.list"

file "$OUT/init"
sha256sum "$OUT/init" "$OUT/initramfs.list"
