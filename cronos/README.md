# cronos: Echo Show 5, 2nd generation (MediaTek MT8163)

`build.sh` builds Linux 7.2.13 for the Echo Show 5 2nd gen (board revision `pvt_4_1`): the kernel,
the device tree and the modules. `uname -r` says `7.2.13-cronos`.

Mainline Linux has no MT8163 support. `patches/0000-mt8163-linux-7.2.patch` carries it: the clocks,
pin controller, power domains, display, sound and the board device trees of Amazon's MT8163 devices,
from the linux-mtk tree (github.com/bengris32/linux-mtk, branch `mt8163/7.0`, commit
`20951722df6ae1f6fecbfcea0a7d585118a06f3f`), adapted to 7.2. The other patches are small fixes on top.
[PROVENANCE.md](PROVENANCE.md) lists where each one comes from.

## What works, on paper

This build is the start of the Echo Show 5's kernel, not all of it: the device tree it ships is
linux-mtk's `mt8163-amazon-cronos-v4.1.dts`, which describes the console, the storage and a few
peripherals. From that device tree and the drivers here, without a test on a unit of this build alone:

| Part | State |
| --- | --- |
| The first CPU core | boots |
| The other three cores | do not start: the boot loader's secure monitor answers PSCI's CPU_ON but leaves the core powered off, and the kernel has no way here to power it |
| Serial console (UART0), eMMC, USB (device mode) | in the device tree |
| GPU (Mali-T720, panfrost), I2C, the ambient light sensor, the volume buttons | in the device tree |
| Display | the drivers are here (`0012`, `0016` for taking the boot loader's picture over); the panel and its node are not |
| Wi-Fi, Bluetooth, touch, sound, camera, privacy switch | the device tree has no nodes for them; the privacy switch's driver (`0009`) is here |

A unit's own kernel on top of this needs a board device tree that describes the rest (the panel and
its supplies, the touch controller, the Wi-Fi chip's power and SDIO host, the sound card), the drivers
for the panel and the sound card, and a way to start the secondary cores.

## Building

    ../build.sh cronos

The output (`../out/cronos` by default):

| File | What it is |
| --- | --- |
| `Image.gz` | the kernel |
| `cronos.dtb` | the device tree, padded to 256 KiB so the boot loader can add to it |
| `modules.tar.gz` | the modules, `lib/modules/<release>/`, ready to unpack into a root filesystem |
| `kernel.config`, `kernel.release` | the configuration and the release string |
| `SHA256SUMS`, `manifest.json` | sums, and the manifest (`../README.md`) |

The configuration is `config/cronos.config`, completed by `make olddefconfig`.

## The display patches

- `0012-display-handover.patch`: the overlay engine is reset when DRM takes over the boot loader's
  scanout, so no transaction the boot loader left in flight survives; the gamma block is put in relay
  mode (no lookup table) when no correction is asked for, as the boot loader leaves it; and mmsys gets
  its reset controller.
- `0016-mt8163-display-first-frame.patch`: on the MT8163 the boot loader sometimes leaves the overlay's
  memory read wedged, and the first frame never completes. When the first enable produces no frame,
  DRM powers the pipeline down, resets the SMI (the memory interface) and the overlay if the device
  tree gives their resets, and enables it again, up to three times. Measured over 160 boots of a unit:
  15 needed it, and all 15 came back in the first cycle, with no false trigger.
