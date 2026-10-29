#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0
"""Point the athena device tree at another of athena's panels.

    panel-dts.py <mt8183-amazon-athena.dts> <panel>

The DTS drives the ILI9881C on BOE glass (jd936x_id=0x36, the boot loader's
ili9881c_wxga_dsi_vdo_st_boe), the one panel its comment at &dsi0 says was tested on a unit. The
other athena panels' init tables are in board/patches/panel, and that comment says what using
one takes: its compatible, and for the JD9365 ones the jadard driver's two supplies, vccio-supply =
<&mt6358_vcama2_reg> and vdd-supply = <&lcd_avee>, in place of the ILI9881C driver's power-supply.

<panel> is the part of the compatible after "amazon,athena-": ili9881c-boe (no change),
jd9365-boe-new, and so on. The boot loader names the unit's panel with jd936x_id= on its command line
(read it in /proc/cmdline; the DTS's comment at &dsi0 says the same); its low nibble is the variant:
"""
import sys

# The panel the boot loader reports by the low nibble of jd936x_id, from the LK panel names in
# board/patches/panel (only the ones whose nibble the patches state).
NIBBLES = {4: "jd9365-boe", 5: "jd9365-boe-new", 6: "ili9881c-boe", 7: "jd9365-inx"}
JD9365 = ("kd-hsd", "kd-hsd-new", "boe", "boe-new", "inx")
ILI9881C_LINE = '\t\tcompatible = "amazon,athena-ili9881c-boe", "ilitek,ili9881c";\n'
SUPPLY_LINE = "\t\tpower-supply = <&lcd_avee>;\n"
PWM_LINE = "\t\tpwms = <&pwm0 0 500000>;\n"
# Units whose LED driver does not follow the display PWM at the DTS's 2 kHz (a 500 us period, kukui's):
# on the BOE-new unit 4% and 100% duty looked the same at 2 kHz and were plainly different at 25 kHz.
# That unit has no LM36274/KTZ8864A backlight chip on any I2C bus.
PWM_PERIOD_NS = {"jd9365-boe-new": 40000}

__doc__ += "".join("    nibble %d: %s\n" % kv for kv in sorted(NIBBLES.items()))
def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    path, panel = sys.argv[1], sys.argv[2]
    with open(path) as f:
        s = f.read()
    if panel == "ili9881c-boe":
        return
    kind, _, variant = panel.partition("-")
    if kind != "jd9365" or variant not in JD9365:
        sys.exit("panel-dts: %s is not one of ili9881c-boe, %s" % (panel, ", ".join("jd9365-" + v for v in JD9365)))
    assert s.count(ILI9881C_LINE) == 1, "panel-dts: the DTS's panel compatible is not the one expected"
    assert s.count(SUPPLY_LINE) == 1, "panel-dts: the DTS's panel supply is not the one expected"
    s = s.replace(ILI9881C_LINE, '\t\tcompatible = "amazon,athena-%s", "jadard,jd9365da-h3";\n' % panel)
    # The DTS gives the panel both drivers' supplies since it learned to pick the panel at boot
    # (panel-athena-select.c); an older one has only the ILI9881C's, which the JD9365's replace.
    if "vccio-supply = <&mt6358_vcama2_reg>;" not in s:
        s = s.replace(SUPPLY_LINE, "\t\tvccio-supply = <&mt6358_vcama2_reg>;\n\t\tvdd-supply = <&lcd_avee>;\n")
    if panel in PWM_PERIOD_NS:
        assert s.count(PWM_LINE) == 1, "panel-dts: the DTS's backlight PWM is not the one expected"
        s = s.replace(PWM_LINE, "\t\tpwms = <&pwm0 0 %d>;\n" % PWM_PERIOD_NS[panel])
    with open(path, "w") as f:
        f.write(s)
    print("panel-dts: amazon,athena-%s" % panel)


if __name__ == "__main__":
    main()
