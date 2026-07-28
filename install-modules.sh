#!/bin/bash
# Install the kernel modules as a Magisk module over adb.
#
# AnyKernel3 already does this itself, but only when it can see a decrypted
# /data - its do_modules() checks for /data/data/android and bails with
# "No /data access for kernel helper systemless module!" otherwise. Flashing
# by recovery sideload on an FBE device hits exactly that: /data is mounted
# but still encrypted, so the kernel gets written and the modules are skipped.
#
# Run this once after sideloading, with the new kernel booted. Flashing the
# zip from the Magisk app instead does the same thing and does not need this.
set -eo pipefail

cd "$(dirname "$0")"
. ./env.sh

SRC=$ROOT/ak3-sailfish/modules/system/lib/modules
[ -d "$SRC" ] || { echo "no staged modules - run ./package.sh first" >&2; exit 1; }

KVER=$(cat "$OUT/include/config/kernel.release" 2>/dev/null || true)
RUNNING=$(adb shell uname -r | tr -d '\r')
if [ -n "$KVER" ] && [ "$KVER" != "$RUNNING" ]; then
	echo "!! phone is running $RUNNING but the build is $KVER" >&2
	echo "   flash the kernel first, or the modules will not match vermagic" >&2
	exit 1
fi

echo ":: pushing $(ls "$SRC"/*.ko | wc -l) modules"
adb push "$SRC" /data/local/tmp/ak3mod >/dev/null

# Mirrors AnyKernel3's do_modules(): same module id, same self-removal script,
# so a later AnyKernel3 flash replaces this cleanly rather than colliding.
KERNEL_STRING=$(sed -n 's/^kernel.string=//p' "$ROOT/ak3-sailfish/anykernel.sh")
adb shell su -c "sh -" <<EOF
set -e
MOD=/data/adb/modules/ak3-helper
rm -rf \$MOD
mkdir -p \$MOD/system/lib/modules
cp -f /data/local/tmp/ak3mod/* \$MOD/system/lib/modules/
cat /proc/version > \$MOD/version
cat > \$MOD/module.prop <<P
id=ak3-helper
name=AK3 Helper Module
version=\$(awk '{print \$3}' /proc/version)
versionCode=1
author=AnyKernel3
description=$KERNEL_STRING
P
cat > \$MOD/post-fs-data.sh <<'P'
#!/system/bin/sh
MODDIR=\${0%/*};
if [ "\$(cat /proc/version)" != "\$(cat \$MODDIR/version)" ]; then
  rm -rf \$MODDIR;
  exit;
fi;
rm -f \$MODDIR/update;
[ -f \$MODDIR/post-fs-data.2.sh ] && . \$MODDIR/post-fs-data.2.sh;
P
touch \$MOD/update
chmod 755 \$MOD/post-fs-data.sh
/system/bin/chcon -hR "u:object_r:system_file:s0" \$MOD
rm -rf /data/local/tmp/ak3mod
echo ":: installed \$(ls \$MOD/system/lib/modules/*.ko | wc -l) modules to \$MOD"
EOF

echo ":: reboot, then check with: adb shell ls /system/lib/modules | wc -l"
