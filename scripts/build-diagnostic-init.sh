#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/build/diagnostic-init}"
CLANG="${CLANG:-clang}"

[[ $# -le 1 ]] || { echo 'Only one diagnostic-init output path may be requested.' >&2; exit 64; }
OUT="$(realpath -m "$OUT")"
[[ "$OUT" == "$ROOT/build" || "$OUT" == "$ROOT/build/"* ]] || {
	echo 'Diagnostic-init output must remain beneath the repository build directory.' >&2
	exit 64
}
[[ "$OUT" != *[[:space:]]* && "$OUT" != *['&|\\']* ]] || {
	echo 'Whitespace and shell metacharacters are not supported in the diagnostic-init output path.' >&2
	exit 64
}
command -v "$CLANG" >/dev/null 2>&1 || { echo "Clang not found: $CLANG" >&2; exit 66; }

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
