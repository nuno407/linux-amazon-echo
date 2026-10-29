# athena: Echo Show 8, 2nd generation (MediaTek MT8183)

`build.sh` builds Linux 7.2.13 for the Echo Show 8 2nd gen and packs it into the boot image its boot
loader (MediaTek's LK, "little kernel") starts. `uname -r` says `7.2.13-athena`.

The board files come from the TECHO5 project's 6.18 kernel (see "The board files" below): the
device tree, the sound card, the panel tables, the 6.18 patches, the configuration and the boot
image packer. `patches/port-7.2.py` carries those patches over to 7.2, and the other scripts
in `patches/` add what this build changes. [PROVENANCE.md](PROVENANCE.md) lists where each one
comes from.

## The board files

They are the TECHO5 project's athena kernel directory, `tools/linux/athena/kernel` of
github.com/HuskerMinion/techo5 at commit `d44e005b2df507bfeae4703fc3e717f34832038a` (MIT, with GPL-2.0
patches and drivers and a GPL-2.0 OR MIT device tree). They are not copied into this repository:
`build.sh` fetches that one directory at that commit (a shallow git fetch that downloads only its
files), checks that it is git tree `460e4e5ea8ae3297a231d05f25b664c82ab0d3b7` and that every file
matches its blob, keeps it in the cache, and copies it into the work directory as `base/` for each
build. What those files say, in code and comments, is that project's.

Our changes to them are in `base-patches/`, applied to that copy:

- `0001-pack-cpuidle.patch`: with `CPUIDLE` set in the environment, `pack.py` leaves `cpuidle.off=1`
  off the command line, for a kernel that can use the CPU idle states (this one, see "CPU idle");
- `0002-check-boot-scp-cpuidle.patch`: `check-boot.py` accepts that command line, and a ramdisk that
  also carries the SCP's firmware (`mediatek/mt8183/scp.img`), which this build adds.

## What works

Each part below works on units that run this kernel with more patches on top (an overlay, see
`../README.md`). The build from this repository alone has those parts and not the others, but has not
been booted on its own yet.

| Part | State |
| --- | --- |
| CPUs (eight cores, two clusters), frequency scaling, thermal throttling | works |
| CPU idle: the cores and the clusters powered off between wakes (`patches/mcdi.py`) | works |
| eMMC, USB | works |
| Display: ILI9881C panel (the default), JD9365 BOE-new panel (`PANEL=jd9365-boe-new`) | works, with brightness |
| Touch screen, volume and mute buttons, camera shutter switch, ambient light sensor (TCS3400) | works |
| Sound: the TAS5805M amplifier, the four microphones, the echo reference | works; the amplifier runs without the unit's own tuning (its slot in the device tree is empty) |
| Wi-Fi and Bluetooth (MT7663 on SDIO) | works, with linux-firmware's firmware; the radio's temperature is read |
| GPU (Mali-G72 MP3, panfrost) | works, 300 to 800 MHz, under the die's thermal zone |
| JPEG encoder (mtk-jpeg) | works |
| SCP (the media co-processor) with linux-firmware's firmware, and the MDP3 scaler and converter through it | works |
| Camera (OmniVision OV13855, `patches/athena-camera.py`): packed 10-bit raw frames, 2112x1568 or the whole 4224x3136 array | works |
| ISP pass 2 in front of the MDP3 (`patches/mdp3-mt8183-isp.py`), face detector (`patches/mtk-fd.py`) | in the tree, not enabled: they need SCP firmware support that is not in this repository |
| Hardware video decoding and encoding, the other media blocks | not in this build |

## Building

    ../build.sh athena

`MCDI_CPUS` chooses the cores that take the CPU idle states (see "CPU idle"): every core by default,
a list like `4,5,6,7` for those cores at CPU level only, or `off`, which leaves every core in WFI and
puts `cpuidle.off=1` on the command line.

`PANEL` picks the panel the device tree drives, as `patches/panel-dts.py` names it: `ili9881c-boe`
(the default) or one of the JD9365 panels, `jd9365-boe-new` and the others. The boot loader names
the unit's panel with `jd936x_id=` on the kernel command line it passes (readable in
`/proc/cmdline`); its low nibble is the variant: 4 `jd9365-boe`, 5 `jd9365-boe-new`, 6 `ili9881c-boe`,
7 `jd9365-inx`. Only the ILI9881C and the JD9365 BOE-new panel have been tried on a unit.

The output (`../out/athena` by default):

| File | What it is |
| --- | --- |
| `boot-athena.img` | the boot image: Android boot image header v1, `Image.gz` with the device tree appended, and the ramdisk |
| `Image.gz`, `athena.dtb` | the kernel and the device tree |
| `ramdisk.cpio.gz` | the ramdisk: firmware files only, and no `/init` |
| `kernel.config`, `kernel.release` | the configuration and the release string |
| `config-dropped.txt` | options the 6.18 configuration set that 7.2 no longer has, for review |
| `SHA256SUMS`, `manifest.json` | sums, and the manifest (`../README.md`) |

The base's `check-boot.py` checks the boot image before the build finishes.

## The boot image

The kernel has its drivers built in and ships no modules. The ramdisk holds the firmware the drivers
load (MediaTek's MT7663 Wi-Fi and Bluetooth firmware and the SCP firmware, from linux-firmware, under
`LICENCE.mediatek`) and nothing else: the boot loader adds `root=` and `init=` for the system
partition, and the kernel, finding no `/init` in the ramdisk, mounts that and runs it. The image's
header and command line are the base's `pack.py`'s.

The amplifier's tuning has a slot in the device tree (the base's `dsp_slot.py`), left empty: a tuning is
specific to the unit's speaker and is not shipped here. An installer may fill the slot from the
unit's own boot image.

## Carried over to 7.2

`patches/port-7.2.py` runs before the base patches:

| Step | Why |
| --- | --- |
| `jd9365` binding | 7.2's `jadard,jd9365da-h3` binding lists more panels, so `panel/0003` no longer applies. The script adds the five `amazon,athena-jd9365-*` compatibles to the enum itself, and `patch-display.py` then skips 0003. |
| `jd9365` driver | 7.2's `jadard_panel_desc` points at its mode (`mode_4ln`) where 6.18's held it inline (`mode`). The script applies `panel/0004` and moves its five panel descriptions to the pointer; `patch-display.py` then skips 0004. |
| `tcs3400` | 7.2's `tcs3472.c` logs through a local `dev` in probe, and its i2c id table uses `.name =`. The script runs `patch-tcs3400.py` with those two spellings translated. |

The configuration is the base's `athena_defconfig`, the 6.18 one, with 7.2's new options at their defaults
(`make olddefconfig`) and the changes in `config`. The build checks the options in `config.want`.

## The JD9365 BOE-new panel

It took four changes, each found on a unit with that panel:

| Patch | What it does | Without it |
| --- | --- | --- |
| `jd9365-dsi-mode.py` | burst video with `MIPI_DSI_MODE_LPM` on the five JD9365 descriptions: panel/0004 sets no mode flags, so its init table went out in high-speed mode | dark screen, no error |
| `mtk-dsi-cmd-clock-lp.py` | mediatek-dsi's clock lane stays in LP (low power) while commands go out, and runs continuously for video | the table takes at some boots only, or the picture flickers |
| `jd9365-dsi-mode.py` (the line) | the boot loader's line: 478 Mbps a lane, HSA/HBP/HFP 56/110/235 bytes (22/32/108-pixel porches at 79.68 MHz) | 415 Mbps and a 34-byte front porch: the picture moved and flickered |
| `panel-dts.py` (backlight) | the display PWM at 25 kHz (a 40 us period) in place of the device tree's 2 kHz | 4% and 100% duty looked the same |

The boot loader's line was read from the DSI and MIPI TX registers it leaves running when the kernel
starts (`patches/mtk-dsi-dump-boot-regs.py`, a diagnostic, not part of the build).
`jd9365-power-mode-log.py` logs the panel's reply to a DCS (display command set) read after the init
table: `panel power mode 0x9c` says the table took, a read that times out says it did not.

## The SCP and the MDP3

The SCP, the MT8183's Cortex-M4 media co-processor, runs linux-firmware's `mediatek/mt8183/scp.img`
(kukui_scp v2.0.13324, the one ChromeOS ships for the MT8183 Chromebooks). `patches/scp-dts.py` turns
it on and puts its memory back at 0x50000000, where that firmware expects it; its console is in
debugfs (`cros_scp/console_log`).

The MDP3 (`/dev/video*` named `mtk-mdp3:m2m`) scales, crops, rotates and converts between YUV and RGB
layouts, planned on the SCP and run by the AP's command engine (GCE). Mainline's driver uses the
shared structures of an SCP firmware that was never published, and every frame failed;
`patches/mdp3-mt8183-cros-abi.py` gives it the layout of the ChromeOS 5.10 kernel, which this firmware
speaks. 1080p NV12 to 720p YUYV runs at well over 25 frames a second for almost no CPU.

## The camera

The OV13855 (13 MP, four-lane CSI-2) runs one fixed path, which `patches/mt8183-athena-camera.c`
drives itself: mainline has no MT8183 sensor interface or ISP driver.

```
OV13855 --4 lanes--> CSI0 D-PHY --> seninf1 --> MUX0 --> CAM2 --> CAMSV1 --IMGO DMA (larb6)--> /dev/videoN
```

| Part | From |
| --- | --- |
| Wiring | the board files' device tree (its camera section): I2C2 address 0x36 (EEPROM at 0x54), reset GPIO102, power-down GPIO177, MCLK on CMMCLK0 (GPIO99), vcama1 2.8 V, vcamd 1.2 V, vcamio 1.8 V, CAMSV1 interrupt 258. `patches/camera-dts.py` replaces that section with the node this driver takes |
| Sensor tables | MediaTek's `ov13855_mipi_raw` imgsensor driver (`sensor_init` and `preview_setting`: 2112x1568 binned, 540 Mbps a lane), with the frame stretched for the exposure; its 15 frames a second `capture_setting` for the whole array, kept at 540 Mbps with a longer line, about 7 frames a second (PROVENANCE.md) |
| D-PHY, seninf, CAMSV | the MT8183 bring-up of BayLibre's MT8365 seninf/CAMSV drivers (github.com/vpavlin/mt8183-camera) |

The video node is `athena-ov13855`: four pixels in five bytes, least significant bits first, the first
pixel blue; `V4L2_CID_EXPOSURE` in lines and `V4L2_CID_ANALOGUE_GAIN` in 1/64. CAMSV's `IMGO_ERR`
(bit 16) stays raised for the whole stream while every frame is whole and correct, so the driver
leaves that interrupt off.

## CPU idle

On athena the CPUs' idle power-down and wake-up are done by the SSPM's MCDI firmware, which only
manages the cores the kernel lists as available in its mailbox. Mainline never writes that list, and a
core that took mainline's PSCI idle state never woke. `patches/mcdi.py` adds `athena-mcdi.c`, which
keeps the list as Amazon's MT8183 kernel does (PROVENANCE.md), and with it every core takes mainline's
CPU-level and cluster-level idle states. If the SSPM's MCDI task does not answer at boot, cpuidle is
turned off and the cores idle in WFI.
