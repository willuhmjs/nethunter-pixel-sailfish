#!/bin/bash
# Fetch the LineageOS kernel source and the toolchains, then lay the NetHunter
# changes on top. Idempotent: re-running resets the tree back to the pinned
# baseline before re-applying, so a half-finished run is not a problem.
set -eo pipefail

cd "$(dirname "$0")"
ROOT=$(pwd)

KREPO=https://github.com/LineageOS/android_kernel_google_marlin.git
KBRANCH=lineage-22.2
# LOS 22.2 marlin, kernel 4.4.302. Pinned so a CI build is reproducible.
KCOMMIT=e9cde652c238d7a610789cd25c2a6aa803cfe192

TCBASE=https://kali.download/nethunter-images/toolchains
TARBALLS="google_clang-10.0.4.tar.xz google_aarch64-4.9.tar.xz google_armhf-4.9.tar.xz"

# --- toolchains ------------------------------------------------------------
mkdir -p toolchains
for t in $TARBALLS; do
	# clang-10.0.4 unpacks into a directory called clang-10.0
	dir=toolchains/$(echo "${t#google_}" | sed 's/\.tar\.xz$//; s/^clang-10\.0\.4$/clang-10.0/')
	[ -d "$dir" ] && { echo ":: have $dir"; continue; }
	echo ":: fetching $t"
	curl -fL --retry 3 -o "toolchains/$t" "$TCBASE/$t"
	mkdir -p "$dir"
	tar -xf "toolchains/$t" -C "$dir"
done

# --- kernel source ---------------------------------------------------------
if [ ! -d src/kernel/.git ]; then
	echo ":: cloning $KREPO ($KBRANCH)"
	mkdir -p src
	git clone --depth 200 -b "$KBRANCH" "$KREPO" src/kernel
fi

cd src/kernel
git -c advice.detachedHead=false fetch --depth 200 origin "$KBRANCH"
git -c advice.detachedHead=false checkout -f "$KCOMMIT"
git clean -qfdx -e out

# --- NetHunter changes -----------------------------------------------------
echo ":: applying patches"
git apply --whitespace=nowarn "$ROOT"/patches/*.patch

echo ":: copying overlay"
cp -a "$ROOT"/overlay/. .

echo ":: ready - now run ./build.sh"
