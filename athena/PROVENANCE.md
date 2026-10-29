# athena: where each part comes from

Every patch, driver and setting here is one of the following. The board files the build fetches from
the TECHO5 project are not here; see "The board files" below.

- **mainline**: from the Linux kernel, a kernel.org release or a public mainline driver, cited;
- **public tree**: from another public, licensed source tree, cited with its commit or branch;
- **our own**: written for this kernel from the mainline sources, public documentation (such as the
  MIPI DSI and DCS specifications), and what a unit's own running Linux shows (its registers, its
  `/proc` and `/sys` files, its logs), or black-box tests on a unit.

Anything derived from a vendor's unpublished or proprietary sources is not in this repository.

## Inputs

| Input | Source |
| --- | --- |
| Linux 7.2.13 | kernel.org, `linux-7.2.13.tar.xz`, sha256 `08e7b0c4f2dd1971f972da274b5e589a98989390ac56acd7a1a5af922363ea6c` |
| The board files | the TECHO5 project, `tools/linux/athena/kernel` at commit `d44e005b2df507bfeae4703fc3e717f34832038a`, git tree `460e4e5ea8ae3297a231d05f25b664c82ab0d3b7`, fetched at build time |
| MT7663 Wi-Fi and Bluetooth firmware, MT8183 SCP firmware | linux-firmware, tag `20260916`, each file pinned by sha256 in `build.sh`; MediaTek's redistribution license `LICENCE.mediatek` |

## The board files (fetched, not in this repository)

`build.sh` fetches `tools/linux/athena/kernel` of the TECHO5 project at commit
`d44e005b2df507bfeae4703fc3e717f34832038a` and checks it against git tree
`460e4e5ea8ae3297a231d05f25b664c82ab0d3b7`. That directory is TECHO5's (MIT; its patches and drivers
GPL-2.0, its device tree GPL-2.0 OR MIT), and so is what its files and comments say: its own provenance
is that project's. The build uses its device tree, `athena_defconfig`, `src/mt8183-athena.c`,
`src/panel/panel-athena-select.c`, `patches/0001`, `patches/panel/0001`-`0005`, the `patches/patch-*.py`
the series names, `dsp_slot.py`, `mkfwcpio.py`, `pack.py` and `check-boot.py`.

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
| `mdp3-cached-capture.py` | our own | mainline vb2 (`V4L2_MEMORY_FLAG_NON_COHERENT`) and mtk-mdp3 |
| `mdp3-rgba.py` | our own | mainline mtk-mdp3's format table and `MDP_COLOR_RGBA8888` (`mtk-mdp3-regs.h`) |
| `wdt-kexec.py` | our own | mainline mtk_wdt and the watchdog core |

## Configuration

`config` and `config.want` are our own: options of mainline 7.2.
