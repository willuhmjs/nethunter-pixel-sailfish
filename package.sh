#!/bin/bash
# Package the built kernel + modules into a flashable AnyKernel3 zip for
# sailfish (Google Pixel 1) on LineageOS 22 / Android 15.
set -eo pipefail

cd "$(dirname "$0")"
. ./env.sh

KVER=$(cat "$OUT/include/config/kernel.release")
IMAGE="$OUT/arch/arm64/boot/Image.lz4-dtb"
AK3="$ROOT/ak3-sailfish"
MODDIR="$AK3/modules/system/lib/modules"
ZIP="$ROOT/NetHunter-sailfish-${KVER}.zip"

[ -f "$IMAGE" ] || { echo "no kernel image - run the build first" >&2; exit 1; }

echo ":: kernel release  $KVER"

# --- modules ---------------------------------------------------------------
# Strip and stage via modules_install so we get a consistent set, then flatten
# into one directory (NetHunter's convention, and what insmod-by-path expects)
# and re-run depmod so modules.dep/alias refer to the flat names.
rm -rf "$ROOT/staging" "$ROOT/modflat"
mkdir -p "$ROOT/staging"
kmake INSTALL_MOD_PATH="$ROOT/staging" INSTALL_MOD_STRIP=1 modules_install >/dev/null

FLAT="$ROOT/modflat/lib/modules/$KVER"
mkdir -p "$FLAT"
find "$ROOT/staging" -name '*.ko' -exec cp -f {} "$FLAT/" \;
depmod -b "$ROOT/modflat" -F "$OUT/System.map" "$KVER" 2>/dev/null
# the .bin caches are keyed to a real /lib/modules layout; drop them
rm -f "$FLAT"/*.bin "$FLAT"/modules.devname "$FLAT"/modules.softdep \
      "$FLAT"/modules.weakdep

rm -rf "$MODDIR"
mkdir -p "$MODDIR"
cp -f "$FLAT"/*.ko "$FLAT"/modules.dep "$FLAT"/modules.alias \
      "$FLAT"/modules.symbols "$MODDIR/"
echo ":: modules         $(ls "$MODDIR"/*.ko | wc -l) ($(du -sh "$MODDIR" | cut -f1))"

# --- kernel ----------------------------------------------------------------
cp -f "$IMAGE" "$AK3/Image.lz4-dtb"
echo ":: kernel image    $(du -h "$AK3/Image.lz4-dtb" | cut -f1)"

# boot is a fixed 32 MB raw partition (BOARD_BOOTIMAGE_PARTITION_SIZE
# 0x02000000) and AnyKernel3 only finds out it does not fit after it has
# already unpacked the live boot image on the phone. Do the arithmetic here
# instead: page-aligned header + kernel + the stock ramdisk, which we reuse
# untouched. Anything over and the flash aborts in recovery.
BOOT_MAX=33554432
RAMDISK_SZ=9343984	# LOS 22 sailfish boot.img, xz
page_round() { echo $(( ( ($1 + 4095) / 4096 ) * 4096 )); }
boot_sz=$(( 4096 + $(page_round "$(stat -c%s "$IMAGE")") + $(page_round $RAMDISK_SZ) ))
if [ "$boot_sz" -gt "$BOOT_MAX" ]; then
	echo "!! boot image would be $boot_sz bytes, $((boot_sz - BOOT_MAX)) over the partition" >&2
	exit 1
fi
echo ":: boot image      $boot_sz of $BOOT_MAX bytes ($(( (BOOT_MAX - boot_sz) / 1024 )) KiB spare)"

# --- zip -------------------------------------------------------------------
rm -f "$ZIP"
( cd "$AK3" && zip -r9 "$ZIP" . -x '.git*' '*/.git*' >/dev/null )
echo ":: wrote           $ZIP ($(du -h "$ZIP" | cut -f1))"
