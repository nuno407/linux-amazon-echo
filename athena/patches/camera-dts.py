#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0
"""Add athena's camera to the device tree: the node patches/mt8183-athena-camera.c drives.

    camera-dts.py <mt8183-amazon-athena.dts>

The series runs it right after panel-dts.py, on every panel.

The wiring is the one the board files' DTS gives in its camera section
(board/dts/mt8183-amazon-athena.dts, PROVENANCE.md): the OV13855 at 0x36 on the bit-banged I2C2
(with its EEPROM at 0x54, unused), reset GPIO102 and power-down GPIO177 (low while off), MCLK on
CMMCLK0 (GPIO99 function 1) at 24 MHz, and vcama1 2.8 V, vcamd 1.2 V, vcamio 1.8 V; CSI0 with four
lanes, seninf at 0x1a040000, and CAMSV1 (interrupt 258).

That section describes a seninf/CAMSV driver chain this kernel does not have. This kernel drives the
same sensor, pins and registers through the node below, and the OV13855's address on I2C2 is taken by
whichever node holds it first, so that section goes: the two do not run together.
"""
import sys

CAMERA = """
/* OV13855 camera: patches/camera-dts.py, driven by patches/mt8183-athena-camera.c */
&mt6358_vcama1_reg {
	regulator-min-microvolt = <2800000>;
	regulator-max-microvolt = <2800000>;
};

&mt6358_vcamd_reg {
	regulator-min-microvolt = <1200000>;
	regulator-max-microvolt = <1200000>;
};

&mt6358_vcamio_reg {
	regulator-min-microvolt = <1800000>;
	regulator-max-microvolt = <1800000>;
};

&pio {
	camera_pins: camera-pins {
		pins-mclk {
			pinmux = <PINMUX_GPIO99__FUNC_CMMCLK0>;
		};
		pins-control {
			pinmux = <PINMUX_GPIO102__FUNC_GPIO102>,
				 <PINMUX_GPIO177__FUNC_GPIO177>;
			output-low;
		};
	};
};

/ {
	camera@1a040000 {
		compatible = "amazon,athena-camera";
		reg = <0 0x1a040000 0 0x8000>,	/* seninf */
		      <0 0x1a050000 0 0x1000>,	/* CAMSV1 */
		      <0 0x11c80000 0 0x2000>;	/* MIPI CSI0 A and B */
		reg-names = "seninf", "camsv", "csi";
		interrupts = <GIC_SPI 258 IRQ_TYPE_LEVEL_LOW>;
		clocks = <&camsys CLK_CAM_CAM>, <&camsys CLK_CAM_CAMTG>,
			 <&camsys CLK_CAM_SENINF>, <&camsys CLK_CAM_CAMSV0>,
			 <&topckgen CLK_TOP_MUX_SENINF>, <&topckgen CLK_TOP_MUX_CAMTG>;
		clock-names = "cam", "camtg", "seninf", "camsv", "seninf-top", "mclk";
		/* 24 MHz MCLK */
		assigned-clocks = <&topckgen CLK_TOP_MUX_CAMTG>;
		assigned-clock-parents = <&topckgen CLK_TOP_UNIVP_192M_D8>;
		power-domains = <&spm MT8183_POWER_DOMAIN_CAM>;
		/* larb6; which port the CAMSV writes through is not known, so all candidates */
		iommus = <&iommu M4U_PORT_CAM_IMGO>, <&iommu M4U_PORT_CAM_SOCO>,
			 <&iommu M4U_PORT_CAM_SOC1>, <&iommu M4U_PORT_CAM_SOC2>;
		pinctrl-names = "default";
		pinctrl-0 = <&camera_pins>;
		dovdd-supply = <&mt6358_vcamio_reg>;
		avdd-supply = <&mt6358_vcama1_reg>;
		dvdd-supply = <&mt6358_vcamd_reg>;
		reset-gpios = <&pio 102 GPIO_ACTIVE_LOW>;
		powerdown-gpios = <&pio 177 GPIO_ACTIVE_LOW>;
		sensor-bus = <&i2c2_gpio>;
	};
};
"""


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    path = sys.argv[1]
    with open(path) as f:
        s = f.read()
    assert "amazon,athena-camera" not in s, "camera-dts: the DTS already has the camera"
    banner = s.find("/* ======================= Camera ======================= */")
    if banner >= 0:
        s = s[:banner].rstrip("\n") + "\n"
    assert "i2c2_gpio: i2c-gpio-2" in s, "camera-dts: the DTS's bit-banged I2C2 is not the one expected"
    s += CAMERA
    with open(path, "w") as f:
        f.write(s)


if __name__ == "__main__":
    main()
