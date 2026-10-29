#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0
"""Carry the athena base patches (base/patches, from the TECHO5 project, written against 6.18.56)
over to Linux 7.2. Run before those patchers; build.sh does. Each step is idempotent.

  jd9365  7.2's jadard,jd9365da-h3 binding lists more panels than 6.18's, so panel/0003 no longer
          applies. The athena compatibles are added to its enum here, in order, which also makes
          patch-display.py skip 0003 (it checks for amazon,athena-jd9365-boe first).
          The driver patch (panel/0004) is applied here too, and its five panel descriptions are moved
          from 6.18's inline `mode` to 7.2's `mode_4ln` pointer. panel/0005 (#187, the BOE-new
          panel's DSI link) is written against 6.18's inline mode and is skipped here: on
          7.2 jd9365-dsi-mode.py gives that panel the boot loader's 478 Mbps line, tried on a unit,
          and mtk-dsi-cmd-clock-lp.py its clock lane; 0005's clock lane in LP between lines and EoT
          packets are not carried over (untried here).
  tcs3400 7.2's tcs3472.c spells two things differently from 6.18's: probe logs through a local
          `dev`, and the i2c id table uses `.name =`. patch-tcs3400.py is run with its anchors
          (and the code it puts in their place) translated to that spelling, so its change is
          otherwise exactly upstream's.

Usage: port-7.2.py KTREE UPSTREAM_PATCHES
"""
import os
import subprocess
import sys

tree, upstream = sys.argv[1], sys.argv[2]

# jd9365: amazon,athena-jd9365-* into the binding's compatible enum, ahead of the other vendors
p = os.path.join(tree, "Documentation/devicetree/bindings/display/panel/jadard,jd9365da-h3.yaml")
s = open(p).read()
if "amazon,athena-jd9365-boe" not in s:
    a = "    items:\n      - enum:\n"
    assert s.count(a) == 1, "jd9365 binding anchor"
    panels = ["kd-hsd", "kd-hsd-new", "boe", "boe-new", "inx"]
    s = s.replace(a, a + "".join(f"          - amazon,athena-jd9365-{x}\n" for x in panels))
    open(p, "w").write(s)

# jd9365: 7.2's jadard_panel_desc points at its mode (mode_4ln, with an optional mode_2ln) where
# 6.18's held one inline (mode). panel/0004 is applied here and its five descriptions moved to the
# pointer; patch-display.py then finds the driver patched and skips 0004.
p = os.path.join(tree, "drivers/gpu/drm/panel/panel-jadard-jd9365da-h3.c")
s = open(p).read()
if "amazon,athena-jd9365-boe" not in s:
    subprocess.run(["patch", "-p1", "-N", "-s", "--no-backup-if-mismatch", "-i",
                    os.path.join(upstream, "panel/0004-drm-panel-jd9365da-add-amazon-athena-panels.patch")],
                   cwd=tree, check=True)
    s = open(p).read()
inline = "\t.mode = {\n"
if inline in s:
    assert s.count(inline) == 5, ("jd9365 athena descriptions", s.count(inline))
    s = s.replace(inline, "\t.mode_4ln = &(const struct drm_display_mode) {\n")
    open(p, "w").write(s)
# panel/0005: patch-display.py skips it once its marker is in the driver (see above).
boe_new = "static const struct jadard_panel_desc athena_jd_boe_new_desc = {\n"
if "athena: boe-new link" not in s:
    assert s.count(boe_new) == 1, "jd9365 boe-new description"
    s = s.replace(boe_new, "/* athena: boe-new link: jd9365-dsi-mode.py's on 7.2 (port-7.2.py) */\n" + boe_new)
    open(p, "w").write(s)

# tcs3400: run upstream's patcher with 7.2 spellings
src = open(os.path.join(upstream, "patch-tcs3400.py")).read()
for old, new in [
    ('dev_info(&client->dev, ', 'dev_info(dev, '),
    ('\t{ "tcs3400" },\t/* athena: TCS3400 */\n\t{ "tcs3472" },',
     '\t{ .name = "tcs3400" },\t/* athena: TCS3400 */\n\t{ .name = "tcs3472" },'),
    ('\t{ "tcs3472" },\n\t{ }\n};\nMODULE_DEVICE_TABLE(i2c, tcs3472_id);',
     '\t{ .name = "tcs3472" },\n\t{ }\n};\nMODULE_DEVICE_TABLE(i2c, tcs3472_id);'),
]:
    assert old in src, ("patch-tcs3400.py changed", old[:50])
    src = src.replace(old, new)
sys.argv = [os.path.join(upstream, "patch-tcs3400.py"), tree]
exec(compile(src, sys.argv[0], "exec"), {"__name__": "__main__"})
