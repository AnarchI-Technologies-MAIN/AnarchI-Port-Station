#!/usr/bin/env bash
set -euo pipefail

: "${PORTSTATION_ROOT:?Set PORTSTATION_ROOT to the directory containing kernel_source and kernel_build}"
: "${LLVM_ROOT:?Set LLVM_ROOT to the Windows LLVM bin directory expressed as an MSYS path}"

SOURCE="${PORTSTATION_SOURCE:-$PORTSTATION_ROOT/kernel_source}"
OUTPUT="${PORTSTATION_OUTPUT:-$PORTSTATION_ROOT/kernel_build}"
HOST_LIBELF_PREFIX="${HOST_LIBELF_PREFIX:-$PORTSTATION_ROOT/host_libelf/prefix}"
TARGET="${1:-bzImage}"

export MSYS=winsymlinks:nativestrict
export PKG_CONFIG_PATH="$HOST_LIBELF_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export PATH="$HOST_LIBELF_PREFIX/bin:$PATH"

exec make -j"${JOBS:-2}" -C "$SOURCE" \
	O="$OUTPUT" \
	LLVM="$LLVM_ROOT/" \
	READELF=/usr/bin/readelf \
	HOSTCC=/usr/bin/clang \
	HOSTCXX=/usr/bin/clang++ \
	HOSTLD=/usr/bin/ld \
	HOSTAR=/usr/bin/ar \
	HOSTCFLAGS="-Wno-macro-redefined -Wno-char-subscripts -fno-addrsig -idirafter $SOURCE/include/uapi -idirafter $OUTPUT/arch/x86/include/generated/uapi" \
	HOSTLDFLAGS=--ld-path=/usr/bin/ld \
	"$TARGET"
