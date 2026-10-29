#!/bin/bash
# SPDX-License-Identifier: MIT
#
# athena/build.sh: build Linux 7.2.13 for the Echo Show 8 2nd gen (athena, MT8183) and pack its boot
# image. It runs inside the build container; ../build.sh starts it there. See README.md.
#
# Environment:
#   WORK       work directory: the kernel tree, the staged firmware (default /src/athena)
#   CACHE      where downloads are kept (default $WORK/cache)
#   OUT        output directory for the artifacts (default $WORK/out)
#   KTREE      use this unpacked linux-7.2.13 tree in place instead of a fresh one (every step is
#              idempotent, and make rebuilds only what changed)
#   JOBS       parallel make jobs (default: nproc)
#   PANEL      the unit's panel, as patches/panel-dts.py names it (default ili9881c-boe)
#   MCDI_CPUS  the cores that take the CPU idle states (patches/mcdi.py): a list like 7 or 4,5,6,7
#              (CPU level only), every core by default (CPU and cluster level), or off (all in WFI,
#              with cpuidle.off=1 on the command line)
#   OVERLAY    a directory with athena/overlay.sh, which may add patches, configuration and steps
#              (see README.md, "Overlays")
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
PUB=$HERE
WORK=${WORK:-/src/athena}
JOBS=${JOBS:-$(nproc)}
PANEL=${PANEL:-ili9881c-boe}
MCDI_CPUS=${MCDI_CPUS:-0,1,2,3,4,5,6,7}
[ "$MCDI_CPUS" = off ] && MCDI_CPUS=

KVER=7.2.13
KURL=https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-$KVER.tar.xz
KSHA256=08e7b0c4f2dd1971f972da274b5e589a98989390ac56acd7a1a5af922363ea6c

# MT7663 Wi-Fi/Bluetooth firmware and the MT8183 SCP firmware from linux-firmware, pinned. They ship
# as separate files in the boot image's ramdisk, under MediaTek's license, not linked into the kernel.
FW_TAG=20260916
FW_URL=https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain
FW_FILES="
5e1a65036ccf9f53a6f69d9d8f75a07f546f9a7cec83ca89f24907925c54f079 mediatek/mt7663_n9_rebb.bin
d8b8488f37f65e41ded9a911950afb000d236b36e5aa94ad9650ad0c3a86fd45 mediatek/mt7663_n9_v3.bin
534f2152f9b0f48dfcec9c1727b0bab9a3727a655d76d5ec818cc39a55602336 mediatek/mt7663pr2h.bin
e812442fd631ecbea7d2898c3168cb5780377378a0eed74c14fe8d8057fe547c mediatek/mt7663pr2h_rebb.bin
a90d3f66704d85889945fec5525ea77622549da83aced1aac99828383f8f1805 LICENSES/LICENCE.mediatek
401e9c027b0e105efa9eb9b31683924a8d5f5ab3b1654f0915b174effe2df33d mediatek/mt8183/scp.img
"
RAMDISK_FILES="LICENCE.mediatek mediatek/mt7663_n9_rebb.bin mediatek/mt7663_n9_v3.bin mediatek/mt7663pr2h.bin mediatek/mt7663pr2h_rebb.bin mediatek/mt8183/scp.img"

# What an overlay may change. The build's identity is fixed, so a build is reproducible; it is what
# `uname -v` says, so move the timestamp on whenever the kernel changes.
SERIES=$HERE/series
CONFIG_FRAGMENTS=("$HERE/config")
WANT_FILES=("$HERE/config.want")
LOCALVERSION=${LOCALVERSION:--athena}
KBUILD_BUILD_USER=${KBUILD_BUILD_USER:-builder}
KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST:-athena-build}
KBUILD_BUILD_TIMESTAMP=${KBUILD_BUILD_TIMESTAMP:-2026-10-28 00:00:00 UTC}
KBUILD_BUILD_VERSION=${KBUILD_BUILD_VERSION:-1}
# Set (MCDI_CPUS not off): pack.py leaves cpuidle.off=1 off the command line.
CPUIDLE=${MCDI_CPUS:+1}
ramdisk_hook() { :; }
if [ -n "${OVERLAY:-}" ]; then
	OVL=$(cd "$OVERLAY" && pwd)
	# shellcheck source=/dev/null
	. "$OVL/athena/overlay.sh"
fi

if [ "$(uname -m)" = aarch64 ]; then default_cross=; else default_cross=aarch64-linux-gnu-; fi
export ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE-$default_cross}
export KBUILD_BUILD_USER KBUILD_BUILD_HOST KBUILD_BUILD_TIMESTAMP KBUILD_BUILD_VERSION CPUIDLE
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

# 2. The board files (board/: the 6.18 device tree, sound card, panel tables, patches, configuration
# and boot image packer), copied into the work directory with base-patches/ applied
BASE=$WORK/base
rm -rf "$BASE"
cp -R "$HERE/board" "$BASE"
for p in "$HERE"/base-patches/*.patch; do
	patch -d "$BASE" -p1 -s --no-backup-if-mismatch < "$p"
done

# 3. Firmware, staged as it goes in the ramdisk
FWDIR=$CACHE/linux-firmware-$FW_TAG
echo "$FW_FILES" | while read -r sha path; do
	if [ -n "$path" ]; then fetch "$FW_URL/$path?h=$FW_TAG" "$FWDIR/$path" "$sha"; fi
done
STAGE=$WORK/ramdisk-firmware
rm -rf "$STAGE"
install -D -m 644 "$FWDIR/LICENSES/LICENCE.mediatek" "$STAGE/LICENCE.mediatek"
for f in $RAMDISK_FILES; do
	[ "$f" = LICENCE.mediatek ] || install -D -m 644 "$FWDIR/$f" "$STAGE/$f"
done
ramdisk_hook "$STAGE"

# 4. Board files and patches, one step a line of the series, in order
DTSDIR=$KTREE/arch/arm64/boot/dts/mediatek
DTS=$DTSDIR/mt8183-amazon-athena.dts
OVL=${OVL:-}
export PUB BASE OVL KTREE DTSDIR DTS PANEL WORK
while IFS= read -r step; do
	case $step in ''|'#'*) continue;; esac
	(cd "$WORK" && eval "$step") || { echo "series step failed: $step" >&2; exit 1; }
done < "$SERIES"

# 5. Configuration: the 6.18.56 configuration from the base, with 7.2's new options at their defaults
cd "$KTREE"
export KCFLAGS="-fdebug-prefix-map=$KTREE=." KAFLAGS="-fdebug-prefix-map=$KTREE=."
cp "$BASE/athena_defconfig" .config
scripts/config --set-str LOCALVERSION "$LOCALVERSION"
for frag in "${CONFIG_FRAGMENTS[@]}"; do
	while IFS= read -r line; do
		case $line in ''|'#'*) continue;; esac
		# shellcheck disable=SC2086
		scripts/config $line
	done < "$frag"
done
make -s olddefconfig
for wants in "${WANT_FILES[@]}"; do
	while IFS= read -r want; do
		case $want in ''|'#'*) continue;; esac
		grep -qxF "$want" .config || { echo "config check failed: $want" >&2; exit 1; }
	done < "$wants"
done
grep -qxF "CONFIG_LOCALVERSION=\"$LOCALVERSION\"" .config || { echo "config check failed: LOCALVERSION" >&2; exit 1; }
# Options the 6.18.56 configuration set that 7.2 dropped or renamed, for review.
grep '^CONFIG_' "$BASE/athena_defconfig" | sort > "$WORK/config-6.18.56"
grep '^CONFIG_' .config | sort > "$WORK/config-$KVER"
comm -23 "$WORK/config-6.18.56" "$WORK/config-$KVER" > "$OUT/config-dropped.txt" || true

# 6. Build
make -s -j"$JOBS" Image.gz mediatek/mt8183-amazon-athena.dtb
cp arch/arm64/boot/Image.gz "$OUT/Image.gz"
cp "$DTSDIR/mt8183-amazon-athena.dtb" "$OUT/athena.dtb"
cp .config "$OUT/kernel.config"
cat include/config/kernel.release > "$OUT/kernel.release"

# 7. Ramdisk and boot image. The kernel has its drivers built in: there is no modules tarball.
python3 "$BASE/mkfwcpio.py" "$STAGE" "$OUT/ramdisk.cpio.gz" $RAMDISK_FILES
python3 "$BASE/pack.py" "$OUT/Image.gz" "$OUT/athena.dtb" "$OUT/ramdisk.cpio.gz" "$OUT/boot-athena.img"
python3 "$BASE/check-boot.py" "$OUT/boot-athena.img"
cd "$OUT"
sha256sum boot-athena.img Image.gz athena.dtb ramdisk.cpio.gz kernel.config kernel.release config-dropped.txt > SHA256SUMS
python3 "$HERE/../common/manifest.py" athena "$KVER" "$KSHA256" . \
	boot-athena.img Image.gz athena.dtb ramdisk.cpio.gz kernel.config kernel.release config-dropped.txt
cat SHA256SUMS kernel.release
