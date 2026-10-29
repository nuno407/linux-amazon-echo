# cronos: where each part comes from

The categories are those of [../athena/PROVENANCE.md](../athena/PROVENANCE.md): mainline, public tree,
our own. Anything derived from a vendor's unpublished or proprietary sources is not in this
repository.

Most of the board's drivers come from Amazon's own kernel for its MT8163 devices, which Amazon
publishes under the GPL. Its copy cited here is **android_kernel_amazon_mt8163**:
github.com/amazon-oss/android_kernel_amazon_mt8163, branch `lineage-18.1`, commit
`b27e73e3b00b1184d33f1ae5aa55dc0a1e8d491f` (Linux 4.9, GPL-2.0). Paths below are in that tree unless
another is named. Its Wi-Fi driver is a separate tree, **android_kernel_amazon_mt76x8-wifi**:
github.com/amazon-oss/android_kernel_amazon_mt76x8-wifi, branch `lineage-18.1`, commit
`214defc87321931c7d2d4444ba40bef56da74e6e` (git tree `0770f0e4f4848cc4c7e51a4cf4816511b6cd9df8`).

## Inputs

| Input | Source |
| --- | --- |
| Linux 7.2.13 | kernel.org, `linux-7.2.13.tar.xz`, sha256 `08e7b0c4f2dd1971f972da274b5e589a98989390ac56acd7a1a5af922363ea6c` |
| Amazon's kernel files the patches and tools port | android_kernel_amazon_mt8163 at the commit above, copied as they are into `../third_party/amazon-mt8163/` with the tree's `COPYING`: `sound/soc/codecs/tlv320aic3101.c` and `.h`, `sound/soc/codecs/tas5805m_mono.h`, `drivers/misc/mediatek/imgsensor/src/mt8163/ov02b10_mipi_raw/ov02bmipiraw_Sensor.c` |
| The MT7668 Wi-Fi driver | android_kernel_amazon_mt76x8-wifi at the commit above, the files the build uses copied as they are into `../third_party/amazon-mt76x8-wifi/` |

Every copied file, its origin and its sha256 are listed in [../SOURCES.md](../SOURCES.md).

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
| `0012-display-dither.patch` | public tree | the dither block's setup in `drivers/misc/mediatek/video/mt8163/dispsys/ddp_dither.c`: `DITHER_REG(0)` = 1, `DITHER_REG(6)` = 0x3004, `DITHER_REG(12)` = 0x11 (registers 0x100, 0x118, 0x130) |
| `0002-cronos-board-dtsi.sh`, `dts/mt8163-amazon-cronos-board.dtsi` | public tree | the board's GPIOs, interrupts, supplies, pins and addresses from `arch/arm64/boot/dts/mediatek/cronos.dtsi`, `cronos_pvt_4_1.dts` and `mt8163.dtsi` (the Wi-Fi's SDIO host and power, the touch controller, the TAS5805M, the ADC, the microphone FPGA, the sound card, the camera, the JPEG encoder and the video codecs, the MDP mutex among `ddp_hal.h`'s MDP ones); written for linux-mtk's `mt8163-amazon-cronos.dtsi` and the mainline bindings; the `amazon,*` compatibles of drivers here are our own |
| `dts/mt8163-amazon-cronos-display.dtsi` | public tree | the panel's reset (pio 83), backlight PWM (pio 59) and supplies (vgp3, vio28) from `cronos.dtsi`; the boot loader's framebuffer at 0x5f900000 as the boot loader passes it (read on a unit) |
| `dts/mt8163-amazon-cronos-bootfix.dtsi` | public tree | the PSCI 0.1 node and the pstore area (0x44410000, 0xe0000 bytes) of `arch/arm64/boot/dts/mediatek/mt8163.dtsi`; the `mt-boot` enable method is ours (`0004`) |
| `dts/mt8163-amazon-cronos-version.dtsi`, `dts/mt8163-amazon-cronos-v4.1-display.dts` | public tree | the `version = "pvt_4_1"` the boot loader selects the device tree by, as in linux-mtk's `mt8163-amazon-cronos-v4.1.dts`; the top-level file is our own |
| `0004-mt8163-mt-boot.sh`, `mt8163-boot.c` | public tree | the secondary cores' power-on and power-off through the SPM after `drivers/misc/mediatek/base/power/mt8163/mt_psci.c` and `mtcmos.c`, as a mainline arm64 `cpu_operations` |
| `0005-cronos-panel-driver.sh`, `panel-amazon-cronos-st7701s.c` | public tree | the timings and supplies of `drivers/misc/mediatek/lcm/st7701s_wsvga_dsi_vdo_cronos/st7701s_wsvga_dsi_vdo_cronos.c` (480x960; front porch, sync and back porch 30/6/20 horizontally, 21/6/16 vertically), on mainline's DRM panel API |
| `0005-mt8163-cronos-sound.sh`, `mt8163-cronos.c` | public tree | the sound card after `sound/soc/mediatek/mt_soc_audio_8163_amzn` (DL1 out of I2S1 and I2S3, the APLL clock, the ADC's `tlv3101_hw_params`), on linux-mtk's MT8163 AFE driver |
| `0006-amazon-spi-pcm.sh`, `amazon-spi-pcm.c` | public tree | the microphone FPGA's protocol of Lab126's `sound/soc/mediatek/mt_soc_audio_8163_amzn/amzn-spi-pcm/amzn-mt-spi-pcm.c` and `dough.h` (GPL-2.0), rewritten for the current ASoC API. The FPGA's bitstream is not in the published source: it is taken from the unit's own boot image (`tools/`) |
| `port-aic3101.py`, `0007-tlv320aic3101.sh` | public tree | Amazon's TLV320AIC3101 driver, `sound/soc/codecs/tlv320aic3101.c` and `.h` (Copyright 2011 Texas Instruments, GPL-2.0), ported to the 7.2 ASoC component API at build time from the copies in `../third_party/amazon-mt8163/` |
| `0008-tas5805m-delay.sh` | public tree | the 0xFE delay instruction in a TAS5805M configuration, as `sound/soc/codecs/tas5805m.c` handles it (`TAS5805M_DELAY` 254) |
| `port-ov02b10.py` | public tree | extracts `sensor_init` of `drivers/misc/mediatek/imgsensor/src/mt8163/ov02b10_mipi_raw/ov02bmipiraw_Sensor.c` (Copyright 2020 MediaTek Inc.) into a header for a camera driver; this repository has none, so nothing here builds it |
| `0011-mt8163-thermal.sh` | public tree | mainline's `auxadc_thermal.c` set up as `drivers/misc/mediatek/thermal/mt8163/mtk_ts_cpu.c` does: the CPU sensor TS3, the AUXADC channel handed over with `AUXADC_CON1_CLR`/`_SET`, `TS_CON1[5:4]` cleared, `TEMPMSRCTL1`'s 0x10e bits cleared |
| `0014-mt8163-vcodec.sh`, `mt8163-vcodec.c` | public tree, and our own | the `/dev/Vcodec` ioctl numbers and structures of `drivers/misc/mediatek/videocodec/mt8163/videocodec_kernel_driver.c` and `.h`, in their 32-bit layout, for MediaTek's AP-driven codec libraries (not part of this repository); the rest is mainline's runtime PM, IOMMU and DMA APIs, and `VCODEC_SHIM_ALLOC` is our own |
| `0015-mt8163-sodi.sh`, `mt8163-sodi.c` | public tree | screen-on deep idle after `drivers/misc/mediatek/base/power/mt8163/mt_spm_internal.c`, `mt_spm_sodi.c`, `mt_cpuidle.c`, `mt_idle.c` and `drivers/misc/mediatek/cirq/mtk_sys_cirq.c` (Copyright 2015 MediaTek Inc., GPL-2.0). The SPM's PCM program `sodi_binary` (`pcm_sodi_v00.04_mt8163_20171227`, 915 words) is the array `mt_spm_sodi.c` carries, word for word. The secure monitor's side of the sequence is from tests on a unit |
| `wifi/build.sh`, `wifi/patches/` | public tree, and our own | builds android_kernel_amazon_mt76x8-wifi's `module/` with its `configs/cronos.config` out of tree; the patches are our own: the 7.0 and 7.2 kernel APIs, the MAC address from the boot loader's IDME area in the device tree, the radio's temperature through the driver's proc interface, informational messages logged as warnings |

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
`config/drivers.config` enables the board's drivers above.

## tools/

| Tool | Category | Reference |
| --- | --- | --- |
| `extract-fpga-fw.py` | our own | finds the microphone FPGA's two bitstreams (`i2s_to_spi_4ch_v208.bin`, `_v193.bin`, the names `amzn-mt-spi-pcm.c` requests) in the unit's own stock boot image. The bitstreams are not in this repository and not in any published source |
| `build-tas5805m-cfg.py` | public tree | the amplifier's settings, the `tas5805m_init_mono_mini` table of `sound/soc/codecs/tas5805m_mono.h`, as a configuration for mainline's tas5805m driver |
| `prepare-firmware.py` | our own | runs the two above, with the Bluetooth firmware and the regulatory database the user supplies, into a firmware directory; reads `tas5805m_mono.h` from `../third_party/amazon-mt8163/`, checked by sha256 |
