#!/bin/sh
# Install the cronos panel driver and the board device tree. Idempotent.
set -e
P=${KDIR:-/src/linux-7.2.13}/drivers/gpu/drm/panel
D=${KDIR:-/src/linux-7.2.13}/arch/arm64/boot/dts/mediatek
cp "$PUB"/patches/panel-amazon-cronos-st7701s.c $P/
grep -q DRM_PANEL_AMAZON_CRONOS_ST7701S $P/Kconfig || cat >> $P/Kconfig <<'K'

config DRM_PANEL_AMAZON_CRONOS_ST7701S
	tristate "Amazon Echo Show 5 (2021) ST7701S panel"
	depends on OF
	depends on DRM_MIPI_DSI
	depends on BACKLIGHT_CLASS_DEVICE
	help
	  The 480x960 DSI panel of the Echo Show 5 (2021, cronos).
K
grep -q DRM_PANEL_AMAZON_CRONOS_ST7701S $P/Makefile || echo 'obj-$(CONFIG_DRM_PANEL_AMAZON_CRONOS_ST7701S) += panel-amazon-cronos-st7701s.o' >> $P/Makefile
cp "$PUB"/dts/mt8163-amazon-cronos-display.dtsi $D/mt8163-amazon-cronos-display.dtsi
cp "$PUB"/dts/mt8163-amazon-cronos-bootfix.dtsi $D/mt8163-amazon-cronos-bootfix.dtsi
cp "$PUB"/dts/mt8163-amazon-cronos-version.dtsi $D/mt8163-amazon-cronos-version.dtsi
cp "$PUB"/dts/mt8163-amazon-cronos-v4.1-display.dts $D/mt8163-amazon-cronos-v4.1-display.dts
grep -q 'mt8163-amazon-cronos-v4.1-display.dtb' $D/Makefile || \
    echo 'dtb-$(CONFIG_ARCH_MEDIATEK) += mt8163-amazon-cronos-v4.1-display.dtb' >> $D/Makefile
