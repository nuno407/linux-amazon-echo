#!/usr/bin/env python3
"""Extract the OV02B10 sensor's initialization (sensor_init) from MediaTek's ov02b10 imgsensor driver
in Amazon's MT8163 kernel into a header for a capture driver.

    port-ov02b10.py <ov02bmipiraw_Sensor.c> <ov02b10-init.h>

The source is drivers/misc/mediatek/imgsensor/src/mt8163/ov02b10_mipi_raw/ov02bmipiraw_Sensor.c of
github.com/amazon-oss/android_kernel_amazon_mt8163 (build.sh fetches it, ../PROVENANCE.md).
"""
import pathlib
import re
import sys
source = pathlib.Path(sys.argv[1]).read_text()
body = source.split('static void sensor_init(void)', 1)[1].split('/* MIPI_sensor_Init */', 1)[0]
items = re.findall(r'write_cmos_sensor\((0x[0-9a-fA-F]+),\s*(0x[0-9a-fA-F]+|MIRROR)\)|usleep_range\((\d+),\s*\d+\)', body)
assert len(items) == 114, f'unexpected sensor initialization: {len(items)} entries'
lines = ['/* SPDX-License-Identifier: GPL-2.0-only */',
         '/* Derived from the pinned MediaTek OV02B10 sensor initialization. */',
         '/* Copyright (C) 2020 MediaTek Inc. */',
         'static const struct sensor_reg { u16 reg, value; } sensor_init[] = {']
for reg, value, delay in items:
    lines.append(f'\t{{ {reg or "0xffff"}, {"0x03" if value == "MIRROR" else value or delay} }},')
lines.append('};\n')
pathlib.Path(sys.argv[2]).write_text('\n'.join(lines))
