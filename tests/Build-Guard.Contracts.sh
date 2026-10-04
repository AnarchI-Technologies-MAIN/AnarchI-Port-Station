#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin:${PATH:-}"

test_dir="${BASH_SOURCE[0]%/*}"
root="$(cd "$test_dir/.." && pwd -P)"
builder="$root/scripts/build-kernel-msys2.sh"
diagnostic_builder="$root/scripts/build-diagnostic-init.sh"

expect_refusal() {
	local name="$1"
	local expected="$2"
	shift 2
	local output
	if output="$("$@" 2>&1)"; then
		echo "$name unexpectedly succeeded." >&2
		exit 1
	fi
	if [[ "$output" != *"$expected"* ]]; then
		echo "$name failed for the wrong reason: $output" >&2
		exit 1
	fi
	echo "$name=PASS"
}

expect_refusal DESTRUCTIVE_TARGET_REFUSAL 'Refusing unsupported Kbuild target' \
	env PORTSTATION_ROOT=/tmp/portstation-contract LLVM_ROOT=/tmp "$builder" mrproper
expect_refusal MULTIPLE_TARGET_REFUSAL 'Only one Kbuild target may be requested' \
	env PORTSTATION_ROOT=/tmp/portstation-contract LLVM_ROOT=/tmp "$builder" bzImage clean
expect_refusal OUTPUT_ESCAPE_REFUSAL 'Kernel output must remain beneath the Port-Station root' \
	env PORTSTATION_ROOT=/tmp/portstation-contract PORTSTATION_OUTPUT=/tmp/portstation-escape LLVM_ROOT=/tmp "$builder" bzImage
expect_refusal FILESYSTEM_ROOT_REFUSAL 'A filesystem root cannot be the Port-Station root' \
	env PORTSTATION_ROOT=/ LLVM_ROOT=/tmp "$builder" bzImage
expect_refusal DIAGNOSTIC_OUTPUT_ESCAPE_REFUSAL 'Diagnostic-init output must remain beneath the repository build directory' \
	"$diagnostic_builder" /tmp/portstation-diagnostic-escape
expect_refusal DIAGNOSTIC_MULTIPLE_OUTPUT_REFUSAL 'Only one diagnostic-init output path may be requested' \
	"$diagnostic_builder" "$root/build/one" "$root/build/two"

echo BUILD_GUARD_CONTRACTS=PASS
