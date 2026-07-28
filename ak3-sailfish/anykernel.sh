### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## NetHunter kernel for Google Pixel (sailfish), LineageOS 22 / Android 15

### AnyKernel setup
# global properties
properties() { '
kernel.string=NetHunter Kernel by willuhmjs - Google Pixel (sailfish) - LineageOS 22 / Android 15
do.devicecheck=1
do.modules=1
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=sailfish
device.name2=Sailfish
device.name3=Pixel
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
BLOCK=/dev/block/bootdevice/by-name/boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference
. tools/ak3-core.sh;

## AnyKernel install
# The LineageOS ramdisk needs no changes: NetHunter's userland ships in the
# NetHunter app/chroot, not in the boot image. Swap the kernel and repack.
dump_boot;

write_boot;
## end install
