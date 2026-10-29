#!/bin/bash
# SPDX-License-Identifier: MIT
#
# cronos/build.sh: build Linux 7.2.13 for the Echo Show 5 2nd gen (cronos, MT8163): the kernel, the
# device tree and the modules. It runs inside the build container; ../build.sh starts it there. See
# README.md.
#
# Environment:
#   WORK       work directory: the kernel tree and its objects (default /src/cronos)
#   CACHE      where downloads are kept (default $WORK/cache)
#   OUT        output directory for the artifacts (default $WORK/out)
#   KTREE      use this unpacked linux-7.2.13 tree in place instead of a fresh one
#   JOBS       parallel make jobs (default: nproc)
#   OVERLAY    a directory with cronos/overlay.sh, which may add patches, configuration and steps
#              (see README.md, "Overlays")
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
PUB=$HERE
WORK=${WORK:-/src/cronos}
JOBS=${JOBS:-$(nproc)}

KVER=7.2.13
KURL=https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-$KVER.tar.xz
KSHA256=08e7b0c4f2dd1971f972da274b5e589a98989390ac56acd7a1a5af922363ea6c

# Amazon's GPL kernel for its MT8163 devices: the files the patches port, fetched at build time from
# this commit and checked by their sha256 (PROVENANCE.md).
AMAZON_URL=https://raw.githubusercontent.com/amazon-oss/android_kernel_amazon_mt8163
AMAZON_COMMIT=b27e73e3b00b1184d33f1ae5aa55dc0a1e8d491f
AMAZON_FILES="
48c771ff26f0f545d8a2efe8f28de8ec19f35c38bb232cc9fc9be0583b093dce sound/soc/codecs/tlv320aic3101.c
343499af4967bad5a6d03fb0ed2af2ac3bc00fdf04fcef55f4e8b7872ef7620c sound/soc/codecs/tlv320aic3101.h
7a75ac0a8cbc19c02d2de8fc43a779fc9c79034b68f4635560bc7dd55b3a5040 drivers/misc/mediatek/imgsensor/src/mt8163/ov02b10_mipi_raw/ov02bmipiraw_Sensor.c
"

# What an overlay may change. The build's identity is fixed, so a build is reproducible; it is what
# `uname -v` says, so move the timestamp on whenever the kernel changes.
SERIES=$HERE/series
CONFIG=$HERE/config/cronos.config
CONFIG_FRAGMENTS=("$HERE/config/drivers.config")
# The device tree the boot image carries, from the tree's arch/arm64/boot/dts/mediatek: the board's,
# dts/mt8163-amazon-cronos-v4.1-display.dts.
DTB_NAME=mt8163-amazon-cronos-v4.1-display
LOCALVERSION=${LOCALVERSION:--cronos}
KBUILD_BUILD_USER=${KBUILD_BUILD_USER:-builder}
KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST:-cronos-build}
KBUILD_BUILD_TIMESTAMP=${KBUILD_BUILD_TIMESTAMP:-2026-10-28 00:00:00 UTC}
KBUILD_BUILD_VERSION=${KBUILD_BUILD_VERSION:-1}
# Called with the installed modules' directory (lib/modules/<release>) before they are packed.
modules_hook() { :; }
if [ -n "${OVERLAY:-}" ]; then
	OVL=$(cd "$OVERLAY" && pwd)
	# shellcheck source=/dev/null
	. "$OVL/cronos/overlay.sh"
fi

export ARCH=arm64
if [ "$(uname -m)" != aarch64 ]; then export CROSS_COMPILE=${CROSS_COMPILE-aarch64-linux-gnu-}; fi
export KBUILD_BUILD_USER KBUILD_BUILD_HOST KBUILD_BUILD_TIMESTAMP KBUILD_BUILD_VERSION
export LC_ALL=C TZ=UTC

CACHE=${CACHE:-$WORK/cache}
OUT=${OUT:-$WORK/out}
mkdir -p "$WORK" "$CACHE" "$OUT"
WORK=$(cd "$WORK" && pwd) OUT=$(cd "$OUT" && pwd) CACHE=$(cd "$CACHE" && pwd)

fetch() { # fetch URL DEST SHA256
	if [ ! -f "$2" ] || ! echo "$3  $2" | sha256sum -c --quiet - 2>/dev/null; then
		mkdir -p "$(dirname "$2")"
		curl -sSfL -o "$2.part" "$1"
		mv "$2.part" "$2"
	fi
	echo "$3  $2" | sha256sum -c --quiet - || { echo "sha256 mismatch: $2" >&2; exit 1; }
}

# apply PATCH: apply a patch to the tree once. A tree it was applied to (a marker in .applied/, as later
# steps may change the same files) or that already has it is left alone.
apply() {
	local mark
	mark=$KTREE/.applied/$(basename "$1").$(sha256sum < "$1" | cut -c1-16)
	[ -e "$mark" ] && return 0
	if (cd "$KTREE" && git apply --check "$1" 2>/dev/null); then
		(cd "$KTREE" && git apply "$1")
	elif ! (cd "$KTREE" && git apply --reverse --check "$1" 2>/dev/null); then
		echo "the kernel source does not match $1" >&2
		return 1
	fi
	mkdir -p "$KTREE/.applied" && touch "$mark"
}

# 1. Kernel source
if [ -n "${KTREE:-}" ]; then
	KTREE=$(cd "$KTREE" && pwd)
	grep -q "^SUBLEVEL = ${KVER##*.}$" "$KTREE/Makefile" || { echo "$KTREE is not linux-$KVER" >&2; exit 1; }
else
	fetch "$KURL" "$CACHE/linux-$KVER.tar.xz" "$KSHA256"
	KTREE=$WORK/linux-$KVER
	rm -rf "$KTREE"
	tar -C "$WORK" -xJf "$CACHE/linux-$KVER.tar.xz"
fi

# 2. Amazon's kernel files, fetched once into the cache and checked
AMZ=$CACHE/amazon-mt8163-${AMAZON_COMMIT:0:12}
echo "$AMAZON_FILES" | while read -r sha path; do
	if [ -n "$path" ]; then fetch "$AMAZON_URL/$AMAZON_COMMIT/$path" "$AMZ/$path" "$sha"; fi
done

# 3. Patches and board files, one step a line of the series, in order. The scripts find the tree in
# KDIR, and Amazon's kernel files in AMZ.
OVL=${OVL:-}
KDIR=$KTREE
export PUB OVL KTREE KDIR WORK AMZ
export -f apply
while IFS= read -r step; do
	case $step in ''|'#'*) continue;; esac
	(cd "$WORK" && eval "$step") || { echo "series step failed: $step" >&2; exit 1; }
done < "$SERIES"

# 4. Configuration
cd "$KTREE"
mkdir -p out
cp "$CONFIG" out/.config
for frag in "${CONFIG_FRAGMENTS[@]}"; do
	cat "$frag" >> out/.config
done
scripts/config --file out/.config --set-str LOCALVERSION "$LOCALVERSION"
make -s O=out olddefconfig
grep -qxF "CONFIG_LOCALVERSION=\"$LOCALVERSION\"" out/.config || { echo "config check failed: LOCALVERSION" >&2; exit 1; }

# 5. Build. The device tree is padded, which leaves the boot loader room for its own additions.
make -s O=out -j"$JOBS" Image.gz dtbs modules
release=$(make -s O=out kernelrelease)
cp out/arch/arm64/boot/Image.gz "$OUT/Image.gz"
dtc -q -I dtb -O dtb -p 262144 -o "$OUT/cronos.dtb" "out/arch/arm64/boot/dts/mediatek/$DTB_NAME.dtb"
cp out/.config "$OUT/kernel.config"
echo "$release" > "$OUT/kernel.release"

# 6. Modules, as lib/modules/<release> under the root of a tarball
R=$WORK/modules-root
rm -rf "$R"
make -s O=out INSTALL_MOD_PATH="$R" modules_install
rm -f "$R/lib/modules/$release/build" "$R/lib/modules/$release/source"
modules_hook "$R/lib/modules/$release"
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -C "$R" -cf - . | gzip -9n > "$OUT/modules.tar.gz"

cd "$OUT"
sha256sum Image.gz cronos.dtb modules.tar.gz kernel.config kernel.release > SHA256SUMS
python3 "$HERE/../common/manifest.py" cronos "$KVER" "$KSHA256" . \
	Image.gz cronos.dtb modules.tar.gz kernel.config kernel.release
cat SHA256SUMS
