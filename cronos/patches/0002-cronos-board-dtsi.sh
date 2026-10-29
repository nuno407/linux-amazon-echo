#!/bin/sh
# Install dts/mt8163-amazon-cronos-board.dtsi into the tree and include it from the cronos dts. Idempotent.
set -e
D=${KDIR:-/src/linux-7.2.13}/arch/arm64/boot/dts/mediatek
cp "$PUB"/dts/mt8163-amazon-cronos-board.dtsi $D/mt8163-amazon-cronos-board.dtsi
grep -q cronos-board $D/mt8163-amazon-cronos.dts || sed -i 's|#include "mt8163-amazon-cronos.dtsi"|#include "mt8163-amazon-cronos.dtsi"\n#include "mt8163-amazon-cronos-board.dtsi"|' $D/mt8163-amazon-cronos.dts
grep -q 'interrupt-controller/irq.h' $D/mt8163-amazon-cronos.dts || sed -i 's|/dts-v1/;|/dts-v1/;\n#include <dt-bindings/interrupt-controller/irq.h>|' $D/mt8163-amazon-cronos.dts
