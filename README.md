# nethunter-pixel-sailfish

Kali NetHunter kernel for the Google Pixel 1 (sailfish), built against the
LineageOS 22.2 / Android 15 marlin tree (msm-4.4, 4.4.302). Ships as an
AnyKernel3 zip.

    4.4.302-willuhmjs-NetHunter

## Features

- mac80211 with the NetHunter injection patches
- USB wifi adapters as modules: rtw88 (8822BU/8822CU/8821CU/8723DU),
  rtl8812au, rtl8xxxu, ath9k_htc, carl9170, rt2800usb, mt7601u, zd1211rw and
  the usual others
- rtw88 firmware is built into the kernel, since /vendor is verity protected
- HID / BadUSB via gadget configfs
- Bluetooth, USB serial (CH341, CP210x, FTDI, PL2303)
- netfilter targets for the MITM tools (TPROXY, NAT, REDIRECT, bridge-nf)

Adapter drivers are modules because boot is only 32 MB and the kernel already
fills 21 MB of it.

## Build

    ./setup.sh     # clone the pinned LOS tree, fetch toolchains, patch
    ./build.sh     # compile
    ./package.sh   # make the zip

CI builds every push; tagging `v*` cuts a release.

## Flash

Back up first:

    adb shell su -c 'dd if=/dev/block/bootdevice/by-name/boot_a' > boot_a.img

From the Magisk app (Modules -> Install from storage) you get the kernel and
the modules in one step.

By recovery sideload you only get the kernel. AnyKernel3 installs the modules
as a systemless Magisk module and skips that when /data is encrypted, which it
always is in recovery.

To get the modules after a sideload, boot the new kernel and then either
install the same zip from the Magisk app (it reflashes the same kernel and
picks up the modules on the way through), or from a PC run:

    ./install-modules.sh

Check it took:

    adb shell uname -r
    adb shell ls /system/lib/modules | wc -l

insmod wants absolute paths, and reports unresolved symbols as "No such file
or directory", so load dependencies first (ath, ath9k_hw, ath9k_common before
ath9k_htc) or use `modprobe -d /system/lib/modules`.

To recover, `fastboot flash boot_a boot_a.img` from the bootloader.

## Two patches worth knowing about

**`-mgeneral-regs-only`.** The LOS tree drops this flag under clang, working
around llvm.org/pr30792, and substitutes `-mno-implicit-float`. Those are not
equivalent. Without it clang builds an FP register save area for variadic
functions and splits the frame, storing the GP varargs below sp before
allocating the space. arm64 has no red zone and 4.4 has no IRQ stack, so an
interrupt in that window lands on top of them. Every printf-style call in the
kernel is affected; it showed up as random oopses in vsnprintf. pr30792 was
fixed years ago, so the patch restores the flag, and build.sh fails if FP/SIMD
shows up outside the NEON crypto and fpsimd routines.

**`want_initramfs`.** AnyKernel3 decompresses the kernel to hexpatch
`skip_initramfs` when Magisk is present, then lets magiskboot recompress it at
default lz4 instead of lz4 -9. That is 2.8 MB bigger and puts the boot image
512000 bytes over the partition, so the flash aborts. Doing the rename in
init/initramfs.c at build time means the hexpatch finds nothing and AnyKernel3
writes the kernel through untouched. The token is inert here anyway, since
CONFIG_INITRAMFS_IGNORE_SKIP_FLAG=y. package.sh also fails now if the image
would not fit.

## Layout

    env.sh              toolchain paths, kmake helper
    setup.sh            fetch sources and toolchains, apply patches
    build.sh            compile
    package.sh          modules, depmod, size check, zip
    install-modules.sh  push modules as a Magisk module
    nethunter.fragment  config deltas from stock
    patches/            patches against the pinned LOS tree
    overlay/            files copied into the kernel tree
    ak3-sailfish/       AnyKernel3 template
