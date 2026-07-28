#!/bin/bash
# Configure and build the NetHunter sailfish kernel.
#   ./build.sh          incremental
#   ./build.sh clean    wipe out/ first
set -eo pipefail

cd "$(dirname "$0")"
. ./env.sh

[ -d "$KDIR" ] || { echo "no kernel source - run ./setup.sh first" >&2; exit 1; }

[ "$1" = clean ] && rm -rf "$OUT"
mkdir -p "$OUT"

kmake nethunter_sailfish_defconfig
kmake Image.lz4-dtb modules

# The whole point of the -mgeneral-regs-only fix is that no kernel code outside
# the explicitly NEON-aware crypto/fpsimd routines may touch FP/SIMD registers.
# Regressing that gives rare, near-undebuggable memory corruption, so fail the
# build rather than ship it.
echo ":: checking for stray FP/SIMD use"
OBJDUMP=$TC/aarch64-4.9/aarch64-4.9/bin/aarch64-linux-android-objdump
stray=$("$OBJDUMP" -d "$OUT/vmlinux" | awk '
	/^ffffff[0-9a-f]* </ { fn = $2 }
	/\t(ldr|str|ldp|stp|ld1|st1|ins|umov|dup|movi|fmov|mov)\t?[ ]*(q|v[0-9]|d[0-9]|s[0-9])/ { print fn }
' | sort -u | grep -vE "fpsimd|cpu_switch_to|_ce_|_ce>|neon_|aes_|sha1_|sha2_|pmull_|crc32" || true)
if [ -n "$stray" ]; then
	echo "!! FP/SIMD outside the NEON-aware routines:" >&2
	echo "$stray" >&2
	exit 1
fi

echo ":: built $(cat "$OUT/include/config/kernel.release")"
