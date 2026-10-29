# athena: where each part comes from

Every patch, driver and setting here is one of the following. The board files in `board/` are
another project's, copied as they are; see "The board files" below.

- **mainline**: from the Linux kernel, a kernel.org release or a public mainline driver, cited;
- **public tree**: from another public, licensed source tree, cited with its commit or branch. Among
  them are vendor kernels published under the GPL: Amazon's kernel for its MT8183 devices, and
  MediaTek drivers as other vendors' published kernels carry them;
- **our own**: written for this kernel from the mainline sources, public documentation (such as the
  MIPI DSI and DCS specifications), and what a unit's own running Linux shows (its registers, its
  `/proc` and `/sys` files, its logs), or black-box tests on a unit.

Anything derived from a vendor's unpublished or proprietary sources is not in this repository.

## Inputs

| Input | Source |
| --- | --- |
| Linux 7.2.13 | kernel.org, `linux-7.2.13.tar.xz`, sha256 `08e7b0c4f2dd1971f972da274b5e589a98989390ac56acd7a1a5af922363ea6c` |
| The board files | `board/`, copied as they are; see "The board files" below and [../SOURCES.md](../SOURCES.md) |
| MT7663 Wi-Fi and Bluetooth firmware, MT8183 SCP firmware | linux-firmware, tag `20260916`, each file pinned by sha256 in `build.sh`; MediaTek's redistribution license `LICENCE.mediatek` |

## The board files (`board/`)

These files are copied byte for byte from github.com/HuskerMinion/techo5, commit `d44e005b2df507bfeae4703fc3e717f34832038a`, path `tools/linux/athena/kernel` (git tree `460e4e5ea8ae3297a231d05f25b664c82ab0d3b7`), under the MIT license in [board/LICENSE](board/LICENSE). Each file and its sha256 are in [../SOURCES.md](../SOURCES.md) and `../sources.json`.

Only the files this build uses are copied, at their paths in that directory: the device tree,
`athena_defconfig`, `src/mt8183-athena.c`, `src/panel/panel-athena-select.c`, `patches/0001`,
`patches/panel/0001`-`0005`, the `patches/patch-*.py` the series names (and `patch-tcs3400.py`, which
`patches/port-7.2.py` runs), `dsp_slot.py`, `mkfwcpio.py`, `pack.py` and `check-boot.py`. Their
patches and drivers are GPL-2.0 and their device tree GPL-2.0 OR MIT, as their SPDX lines say; the
rest is MIT. What they say, in code and comments, and where their own parts come from, is their
authors'.

| Our change | Category | Reference |
| --- | --- | --- |
| `base-patches/0001-pack-cpuidle.patch` | our own | the kernel command line's `cpuidle.off` (mainline `drivers/cpuidle`) |
| `base-patches/0002-check-boot-scp-cpuidle.patch` | our own | accepts the ramdisk with linux-firmware's `mediatek/mt8183/scp.img`, and the command line of 0001 |

## patches/

| Patch | Category | Reference |
| --- | --- | --- |
| `port-7.2.py` | our own | carries the base patches to the 7.2 sources: the `jadard,jd9365da-h3` binding and `jadard_panel_desc.mode_4ln` (mainline 7.2), `tcs3472.c` (mainline 7.2) |
| `gpu-dts.py` | our own, after mainline | the GPU's supplies as mainline's MT8183 Chromebook boards wire them (`arch/arm64/boot/dts/mediatek/mt8183-kukui.dtsi`, `&gpu`); the power model's coefficient is an estimate in the range of Arm's Mali GPUs of its size |
| `panel-dts.py` | our own | the panel compatibles and supplies from the base panel patches and the DTS's own comment; the backlight PWM period from a black-box test on a unit |
| `jd9365-dsi-mode.py` | our own | the mode flags from the MIPI DSI behavior on a unit; the BOE-new line from the DSI registers the boot loader leaves (read on a unit) |
| `jd9365-power-mode-log.py` | our own | MIPI DCS `get_power_mode` (0x0A) and `get_display_id` (0x04) |
| `mtk-dsi-cmd-clock-lp.py` | our own | mainline mediatek-dsi (`mtk_dsi.c`); the clock lane's behavior from tests on a unit |
| `mtk-dsi-dump-boot-regs.py` | our own | a diagnostic: logs the registers the boot loader leaves; not part of the build |
| `mt7663s-temperature.py` | our own, after mainline | mt76's MT7615 PCIe path (`mt7615/pci_init.c`), which registers the hwmon device; the reply's second word as reported for an MT7663E on the linux-wireless list, and read on a unit |
| `mtk-jpeg-enc-error.py` | our own | mainline mtk-jpeg (`mtk_jpeg_enc_irq`); the encoder's status read on a unit |
| `mdp3-mt8183-cros-abi.py` | public tree | the MDP3 and SCP shared structures (`img_ipi_frameparam`, `img_config`) of the ChromeOS 5.10 kernel, chromium.googlesource.com/chromiumos/third_party/kernel, branch `chromeos-5.10`, `drivers/media/platform/mtk-mdp3`, GPL-2.0, which linux-firmware's `scp.img` speaks |
| `scp-dts.py` | public tree, after mainline | the SCP node of mainline's `mt8183.dtsi`; its memory at 0x50000000 as the kukui boards reserve it (`scp_mem_reserved`, mainline `mt8183-kukui.dtsi` and the ChromeOS 5.10 tree) |
| `mdp3-mt8183-isp.py` | public tree | the MT8183 ISP (IMGI) operations of the ChromeOS 5.10 kernel's MDP3, `drivers/media/platform/mtk-mdp3/mtk-mdp3-comp.c` (`init_isp`, `config_isp_frame`, `config_isp_subfrm`, `wait_isp_event`), and the direct links' controls of its `drivers/soc/mediatek/mtk-mmsys.c` (`mtk_mmsys_mdp_isp_ctrl`, `mtk_mmsys_mdp_camin_ctrl`), chromium.googlesource.com/chromiumos/third_party/kernel, branch `chromeos-5.10`, commit `2a10c4d4bfa06ab7dee329a57b573333db542584`, GPL-2.0; put back into mainline's mtk-mdp3. Not enabled on its own: the ISP's pass 2 needs a driver and SCP firmware support not in this repository |
| `mtk-fd.py`, `mtk-fd/` | public tree | the ChromeOS 5.10 kernel's face detector driver, `drivers/media/platform/mtk-isp/fd/mtk_fd_40.c` and `mtk_fd.h` (Copyright 2018 MediaTek Inc., GPL-2.0), same branch and commit, brought to the 7.2 V4L2 API, with an autosuspend delay of our own; the node is that kernel's `arch/arm64/boot/dts/mediatek/mt8183.dtsi`. `CONFIG_VIDEO_MEDIATEK_FD` is not enabled here: on athena the SCP firmware cannot reach the block's registers by itself |
| `mdp3-cached-capture.py` | our own | mainline vb2 (`V4L2_MEMORY_FLAG_NON_COHERENT`) and mtk-mdp3 |
| `mdp3-rgba.py` | our own | mainline mtk-mdp3's format table and `MDP_COLOR_RGBA8888` (`mtk-mdp3-regs.h`) |
| `wdt-kexec.py` | our own | mainline mtk_wdt and the watchdog core |
| `camera-dts.py` | our own, after the board files | the camera's wiring from the camera section of the board files' device tree (`board/dts/mt8183-amazon-athena.dts`): the OV13855 at 0x36 on I2C2, reset GPIO102, power-down GPIO177, MCLK on CMMCLK0 (GPIO99), the vcama1, vcamd and vcamio supplies, CSI0 at 0x11c80000, seninf at 0x1a040000, CAMSV1 and its interrupt 258; the node is our own, for `mt8183-athena-camera.c` |
| `athena-camera.py`, `mt8183-athena-camera.c` | public tree, and our own | the sensor's register tables are those of MediaTek's OV13855 imgsensor driver, `ov13855mipiraw_Sensor.c` (Copyright 2015 MediaTek Inc., GPL-2.0), as published in UMIDIGI's GPL kernel release for the F2, github.com/UMIDIGI-Official/UMIDIGI-F2-Kernel-Source-Code, branch `main`, commit `900e7d5aa061176e759ea2d3d9679b240a76a27a`, `kernel-4.14 0825/drivers/misc/mediatek/imgsensor/src/common/v1/ov13855_mipi_raw/ov13855mipiraw_Sensor.c`: `sensor_init` and `preview_setting` are its tables as they are (without their leading standby write, 0x0100 = 0; the driver streams with its own), and the full-array mode is the 15 frames a second branch of its `capture_setting` ("full size 15fps for PIP"), likewise, with the lane rate kept at preview's (0x0303 = 1, 0x4837 = 0x1c), a longer line (0x380c/0x380d = 0x0960 for 0x08c4) and a longer frame (0x380e/0x380f = 0x0faa for 0x0c8e). The D-PHY, seninf and CAMSV sequences follow the MT8183 bring-up of BayLibre's MT8365 seninf/CAMSV drivers, github.com/vpavlin/mt8183-camera, commit `c00ad163b8fd65ce7a8f1bf241587923b1a90ead`; the rest is our own, on the mainline V4L2 and videobuf2 APIs, and tests on a unit |
| `mcdi.py`, `mcdi/athena-mcdi.c` | public tree, and our own | the MCDI mailbox protocol of Amazon's GPL kernel for its MT8183 devices (Fire HD 10, 9th generation; imported from Amazon's `Fire_HD10_9th_Gen-7.3.2.7-20230127.tar.bz2`), github.com/amazon-mt8183-devs/android_kernel_amazon_mt8183, branch `lineage-18.1`, commit `c09e9ccc558148267d7455874dd691ed77b318c1`: `drivers/misc/mediatek/base/power/mcdi/mcdi_v1/mtk_mcdi.c` (`mcdi_task_pause`: 1 to pause, 0 to run, each acknowledged in PAUSE_ACK; `update_avail_cpu_mask_to_mcdi_controller`; the CPU isolation mask) and `drivers/misc/mediatek/base/power/mcdi/include/mcdi_v1/mtk_mcdi_mbox.h` (the slots); the mailbox's address, SSPM mailbox 3 at 0x10480000, from TF-A, github.com/ARM-software/arm-trusted-firmware, tag `v2.12.0`, `plat/mediatek/mt8183/include/platform_def.h` (`SSPM_MBOX_3_BASE`) and `sspm_reg.h`. That the SSPM needs the list on athena, and that the cluster-level states work without `CLUSTER_n_CAN_POWER_OFF`, from tests on a unit |

## Configuration

`config` and `config.want` are our own: options of mainline 7.2 and of the drivers above.
