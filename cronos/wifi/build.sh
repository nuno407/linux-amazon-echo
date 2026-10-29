#!/bin/sh
# SPDX-License-Identifier: MIT
#
# Build Amazon's MT7668 Wi-Fi driver (gen4, out of tree) against the configured Linux 7.2 kernel.
# Sources: Amazon's tree as copied into ../../third_party/amazon-mt76x8-wifi (../../SOURCES.md), with
# the patches in patches/ applied in order.
#   wifi/build.sh SRC KERNEL_OBJ_DIR BUILD_DIR OUT_KO
set -e
H=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
SRC=${1:?usage: build.sh SRC KERNEL_OBJ_DIR BUILD_DIR OUT_KO}
K=${2:?}
W=${3:?}
rm -rf "$W"; mkdir -p "$W"
cp -a "$SRC/module"/. "$W"/
cp "$SRC/configs/cronos.config" "$W/.config"
sed -i -e "s/^MTK_MET_PROFILING_SUPPORT=yes/MTK_MET_PROFILING_SUPPORT=no/" \
    -e "s/^CFG_GET_TEMPURATURE=n/CFG_GET_TEMPURATURE=y/" \
    -e "s/^CFG_DEFAULT_DBG_LEVEL=.*/CFG_DEFAULT_DBG_LEVEL=0x1/" "$W/.config"
cd "$W"
for p in "$H"/patches/*.patch; do
    patch -p1 -s < "$p" || { echo "$(basename "$p") does not apply" >&2; exit 1; }
    echo "applied $(basename "$p")"
done
make -C "$K" M="$W" ARCH=arm64 MODULE_NAME=mt76x8_wlan -j"$(nproc)" modules
cp "$W/mt76x8_wlan.ko" "$4"
