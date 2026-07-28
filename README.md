# NetHunter kernel for the Google Pixel (sailfish)

A Kali NetHunter kernel for the first-generation Google Pixel, built against the
LineageOS 22.2 / Android 15 `android_kernel_google_marlin` tree (msm-4.4,
4.4.302). Ships as an AnyKernel3 zip.

Kernel string: `4.4.302-willuhmjs-NetHunter`

## What's in it

**Wireless injection** — mac80211 with the NetHunter injection patches, plus
monitor-mode-capable USB adapter drivers built as modules:

| family | driver | chips |
| --- | --- | --- |
| Realtek | `rtw88` | 8822BU, 8822CU, 8821CU, 8723DU |
| Realtek | `rtl8812au` | 8812AU, 8814AU, 8821AU |
| Realtek | `rtl8xxxu`, `rtl8187`, `rtl8192cu` | older RTL USB sticks |
| Atheros | `ath9k_htc`, `carl9170` | AR9271, AR7010, AR9170 |
| Ralink / MediaTek | `rt2800usb`, `rt73usb`, `rt2500usb`, `mt7601u` | |
| misc | `zd1211rw`, `at76c50x`, `p54usb`, `libertas`, `rsi_91x` | |

rtw88 firmware is linked into the kernel via `CONFIG_EXTRA_FIRMWARE` rather than
dropped in `/vendor`, because `/vendor` is dm-verity protected on LineageOS.

**HID / BadUSB** — USB gadget configfs with `f_hid`, plus ACM, ECM, RNDIS, mass
storage and serial functions.

**Other** — Bluetooth (RFCOMM/BNEP/HIDP, `btusb`, `hci_uart`), USB host serial
(CH341, CP210x, FTDI, PL2303), and the netfilter targets NetHunter's MITM tools
need (TPROXY, NAT, MASQUERADE, REDIRECT, mangle, raw, bridge-nf).

The adapter drivers are modules on purpose: `boot` is only 32 MB
(`BOARD_BOOTIMAGE_PARTITION_SIZE 0x02000000`) and the kernel image is already
~21 MB compressed, so building them in would not fit.

`nethunter.fragment` is the readable record of every config option that differs
from stock; `overlay/arch/arm64/configs/nethunter_sailfish_defconfig` is the
merged result that actually gets built.

## Building

CI builds every push and uploads the zip as an artifact; tagging `v*` cuts a
release. To build locally:

```sh
./setup.sh     # clone the pinned LOS kernel, fetch toolchains, apply patches
./build.sh     # configure + compile  (./build.sh clean to start over)
./package.sh   # produce NetHunter-sailfish-<release>.zip
```

`setup.sh` pins the LineageOS tree to a specific commit and fetches the Android
clang 10.0.4 and GCC 4.9 prebuilts from `kali.download`. It is idempotent — it
resets the kernel tree to the baseline before re-applying, so it is safe to
re-run.

### A note on `-mgeneral-regs-only`

`arch/arm64/Makefile` in this tree drops `-mgeneral-regs-only` under clang as a
workaround for [llvm.org/pr30792](https://bugs.llvm.org/show_bug.cgi?id=30792),
substituting `-mno-implicit-float`. That is not equivalent, and on clang 10 it
produces a kernel that boots and then panics at random.

Without the flag, a variadic function still has to build an AAPCS64 FP register
save area. Clang responds by splitting the frame — it stores the GP vararg
registers at negative offsets from `x29` and only allocates that space in a
later `stp q0, q1, [sp,#-256]!`:

```
seq_printf:
    stp  x29, x30, [sp,#-32]!     ; sp -= 32
    mov  x29, sp                  ; x29 == sp
    stp  x2, x3, [x29,#-120]      ; <-- 120 bytes BELOW sp
    stp  x4, x5, [x29,#-104]      ; <-- below sp
    stp  x6, x7, [x29,#-88]       ; <-- below sp
    stp  q0, q1, [sp,#-256]!      ; space finally allocated
```

arm64 Linux has no red zone, and 4.4 has no separate IRQ stack. An interrupt
taken in that three-instruction window pushes its `pt_regs` straight over the
saved varargs. Every printf-style call in the kernel is affected. The symptom
seen here was an oops in `strnlen` under `vsnprintf` — reading
`/proc/<pid>/maps` picked up a stale userspace pointer for a `%s` whose argument
was a string literal.

pr30792 was fixed long ago, so the patch series restores the flag for clang, and
`build.sh` fails the build if FP/SIMD instructions appear outside the
explicitly NEON-aware crypto and `fpsimd` routines.

## Flashing

The zip is AnyKernel3, `IS_SLOT_DEVICE=1`, and only replaces the kernel — it
leaves the ramdisk alone, so an existing Magisk install survives.

Back up your current boot image first:

```sh
adb shell su -c 'dd if=/dev/block/bootdevice/by-name/boot_a' > boot_a.img
adb shell su -c 'dd if=/dev/block/bootdevice/by-name/boot_b' > boot_b.img
```

Then either flash the zip from a custom recovery, or install it from the Magisk
app (Modules → Install from storage). Reboot, and confirm with:

```sh
adb shell uname -a          # expect 4.4.302-willuhmjs-NetHunter
adb shell 'ls /system/lib/modules | head'
```

To recover, `fastboot flash boot_a boot_a.img` (and `boot_b`) from the
bootloader.

## Layout

```
env.sh                 toolchain paths and the kmake helper
setup.sh               fetch sources + toolchains, apply patches and overlay
build.sh               configure, compile, check for stray FP/SIMD
package.sh             flatten modules, depmod, build the AnyKernel3 zip
nethunter.fragment     readable list of config deltas from stock
patches/               patches against the pinned LineageOS tree
overlay/               files copied verbatim into the kernel tree
ak3-sailfish/          AnyKernel3 template
```
