# cronos: where each part comes from

The categories are those of [../athena/PROVENANCE.md](../athena/PROVENANCE.md): mainline, public tree,
our own. Anything derived from a vendor's unpublished or proprietary sources is not in this
repository.

## Inputs

| Input | Source |
| --- | --- |
| Linux 7.2.13 | kernel.org, `linux-7.2.13.tar.xz`, sha256 `08e7b0c4f2dd1971f972da274b5e589a98989390ac56acd7a1a5af922363ea6c` |

## patches/

| Patch | Category | Reference |
| --- | --- | --- |
| `0000-mt8163-linux-7.2.patch` | public tree | linux-mtk, github.com/bengris32/linux-mtk, branch `mt8163/7.0`, commit `20951722df6ae1f6fecbfcea0a7d585118a06f3f`, GPL-2.0 (device trees GPL-2.0-only OR MIT), copyright notices kept; adapted to the 7.2 sources |
| `0001-mt8163-dtsi-thermal-include.patch` | our own | the `dt-bindings/thermal/thermal.h` include `mt8163.dtsi`'s thermal zones need |
| `0003-phy-mtk-mipi-dsi-mt8163-determine-rate.patch` | our own | mainline 7.2's clock API: `.determine_rate` in place of `.round_rate` |
| `0004-clk-mt8163-apmixedsys-register-plls-dev.patch` | our own | mainline 7.2's `mtk_clk_register_plls()`, which takes the device |
| `0012-display-handover.patch` | our own | mainline mediatek-drm and mtk-mmsys; the gamma block's relay mode as the boot loader leaves it, read from its registers on a unit |
| `0016-mt8163-display-first-frame.patch` | our own | mainline mediatek-drm (`mtk_crtc.c`) and the SMI resets; the stall and its recovery measured on a unit over 160 boots |
| `0009-cronos-privacy.sh`, `gpio-privacy-cronos.c` | our own | the GPIO consumer and input APIs; the latch's behavior (software engages it, only the button releases it) from tests on a unit |
| `0013-quiet-probes.sh` | our own | mainline mtk-sd and goodix: expected probe failures logged once a card is known, and the optional touch configuration requested without a warning |

## Patch 0000 against linux-mtk

Checked on 2026-10-29: linux-mtk's changes for each of the 135 files 0000 touches (mainline `v7.0`
against commit `20951722df6ae1f6fecbfcea0a7d585118a06f3f`, whose Makefile says 7.0.0) were applied
to the 7.2.13 file and compared with the 7.2.13 file with 0000 applied.

- 130 files are the same, byte for byte (55 of the 56 files it adds, among them the board device trees,
  the clock, pin controller and sound drivers, and 75 it changes).
- 3 are the same change rebased onto 7.2.13: `mediatek,dither.yaml` (the same line, other context);
  `drivers/iio/light/jsa1212.c` (7.2's i2c id table spells its entries `.name =` and `.driver_data =`,
  and a double space is gone); `drivers/gpu/drm/mediatek/mtk_dsi.c` (7.2's
  `mtk_dsi_switch_to_cmd_mode()` already ends in a plain `return 0`, so the restructuring is not
  needed, and the comment is one line: "MT8163 does not signal VM_DONE when switching to command
  mode.").
- 2 carry a change of ours: the CCORR's fallback compatible is `mediatek,mt8183-disp-ccorr` (10-bit
  coefficients) where linux-mtk has `mediatek,mt8192-disp-ccorr` (11-bit), in `mt8163.dtsi` and in
  `mediatek,ccorr.yaml`. The block holds 0x400 on its diagonal at boot with the engine on (read on a
  unit), which is 1.0 at 10 bits and would be 0.5 at 11; mainline gives the MT8167, the same display
  generation, the same fallback; and with it a color matrix of 1.0 writes 0x400, tested on a unit.

Every file 0000 touches is among linux-mtk's changes. (linux-mtk's branch also carries mainline
changes after 7.0 and drivers for other devices; 0000 takes the MT8163 ones.)

## Configuration

`config/cronos.config` is our own: options of mainline 7.2 and of the linux-mtk drivers.
