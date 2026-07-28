# Build environment for the NetHunter sailfish (Pixel 1) kernel
# Source this:  . ./env.sh
#
# BASH_SOURCE keeps this working from any checkout path, which is what the CI
# runner needs; fall back to $PWD for shells that do not set it.
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD/env.sh}")" && pwd)
TC=${TOOLCHAIN_DIR:-$ROOT/toolchains}

export ARCH=arm64
export SUBARCH=arm64

export CLANG_PATH=$TC/clang-10.0/clang-10.0/bin
export LD_LIBRARY_PATH=$TC/clang-10.0/clang-10.0/lib64:${LD_LIBRARY_PATH:-}
export PATH=$CLANG_PATH:$TC/aarch64-4.9/aarch64-4.9/bin:$TC/armhf-4.9/armhf-4.9/bin:$PATH

export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-android-
export CROSS_COMPILE_ARM32=arm-linux-androideabi-

export LOCALVERSION=-willuhmjs-NetHunter

# Stamp the builder into /proc/version too; without these the string picks up
# the host account and an empty hostname, which reads like a broken build.
export KBUILD_BUILD_USER=willuhmjs
export KBUILD_BUILD_HOST=nethunter

# The 4.4 host tools predate GCC 14's stricter C defaults, so build them with
# the (lenient, gnu11-default) Android clang running natively on x86_64.
export HOSTCC=$CLANG_PATH/clang
export HOSTCXX=$CLANG_PATH/clang++

KDIR=$ROOT/src/kernel
OUT=$ROOT/out
JOBS=$(nproc)

kmake() { make -C "$KDIR" O="$OUT" CC=clang -j"$JOBS" "$@"; }
