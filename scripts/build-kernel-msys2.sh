#!/usr/bin/env bash
set -euo pipefail

: "${PORTSTATION_ROOT:?Set PORTSTATION_ROOT to the directory containing kernel_source and kernel_build}"
: "${LLVM_ROOT:?Set LLVM_ROOT to the Windows LLVM bin directory expressed as an MSYS path}"

SOURCE="${PORTSTATION_SOURCE:-$PORTSTATION_ROOT/kernel_source}"
OUTPUT="${PORTSTATION_OUTPUT:-$PORTSTATION_ROOT/kernel_build}"
HOST_LIBELF_PREFIX="${HOST_LIBELF_PREFIX:-$PORTSTATION_ROOT/host_libelf/prefix}"
TARGET="${1:-bzImage}"

[[ $# -le 1 ]] || { echo 'Only one Kbuild target may be requested.' >&2; exit 64; }

case "$TARGET" in
	defconfig|olddefconfig|prepare|bzImage) ;;
	*)
		echo "Refusing unsupported Kbuild target: $TARGET" >&2
		exit 64
		;;
esac

root_real="$(realpath -m "$PORTSTATION_ROOT")"
source_real="$(realpath -m "$SOURCE")"
output_real="$(realpath -m "$OUTPUT")"
[[ "$root_real" != / && "$root_real" != /[a-zA-Z] ]] || { echo 'A filesystem root cannot be the Port-Station root.' >&2; exit 64; }
[[ "$source_real" == "$root_real/"* ]] || { echo 'Kernel source must remain beneath the Port-Station root.' >&2; exit 64; }
[[ "$output_real" == "$root_real/"* ]] || { echo 'Kernel output must remain beneath the Port-Station root.' >&2; exit 64; }
[[ -f "$source_real/Makefile" ]] || { echo "Kernel source Makefile not found: $source_real" >&2; exit 66; }
[[ "$source_real" != "$output_real" ]] || { echo 'In-tree kernel builds are refused.' >&2; exit 64; }
[[ -x "$LLVM_ROOT/clang.exe" || -x "$LLVM_ROOT/clang" ]] || { echo "LLVM clang not found: $LLVM_ROOT" >&2; exit 66; }
[[ "$source_real$output_real$HOST_LIBELF_PREFIX$LLVM_ROOT" != *[[:space:]]* ]] || {
	echo 'Whitespace in build/tool paths is not supported by this native MSYS2 contract.' >&2
	exit 64
}

expected_version="${PORTSTATION_KERNEL_VERSION:-7.2.8}"
jobs="${JOBS:-2}"
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid JOBS value: $jobs" >&2; exit 64; }
actual_version="$(awk '
	$1 == "VERSION" { version=$3 }
	$1 == "PATCHLEVEL" { patchlevel=$3 }
	$1 == "SUBLEVEL" { sublevel=$3 }
	END { print version "." patchlevel "." sublevel }
' "$source_real/Makefile")"
[[ "$actual_version" == "$expected_version" ]] || {
	echo "Kernel version mismatch: expected $expected_version, found $actual_version" >&2
	exit 65
}

export MSYS=winsymlinks:nativestrict
export PKG_CONFIG_PATH="$HOST_LIBELF_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export PATH="$HOST_LIBELF_PREFIX/bin:$PATH"
unset MAKEFLAGS MFLAGS GNUMAKEFLAGS MAKEFILES MAKEOVERRIDES

exec make -j"$jobs" -C "$source_real" \
	O="$output_real" \
	ARCH=x86_64 \
	KCONFIG_CONFIG=.config \
	LLVM="$LLVM_ROOT/" \
	READELF=/usr/bin/readelf \
	HOSTCC=/usr/bin/clang \
	HOSTCXX=/usr/bin/clang++ \
	HOSTLD=/usr/bin/ld \
	HOSTAR=/usr/bin/ar \
	HOSTCFLAGS="-Wno-macro-redefined -Wno-char-subscripts -fno-addrsig -idirafter $source_real/include/uapi -idirafter $output_real/arch/x86/include/generated/uapi" \
	HOSTLDFLAGS=--ld-path=/usr/bin/ld \
	"$TARGET"
