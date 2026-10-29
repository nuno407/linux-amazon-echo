# cronos: Echo Show 5, 2nd generation (MediaTek MT8163)

`build.sh` builds Linux 7.2.13 for the Echo Show 5 2nd gen (board revision `pvt_4_1`): the kernel,
the device tree and the modules. `uname -r` says `7.2.13-cronos`.

Mainline Linux has no MT8163 support. `patches/0000-mt8163-linux-7.2.patch` carries it: the clocks,
pin controller, power domains, display, sound and the board device trees of Amazon's MT8163 devices,
from the linux-mtk tree (github.com/bengris32/linux-mtk, branch `mt8163/7.0`, commit
`20951722df6ae1f6fecbfcea0a7d585118a06f3f`), adapted to 7.2. The board itself (its device tree in
`dts/`, the panel, the sound card, the microphones, the secondary cores, CPU idle, the thermal
controller, the video codecs' device and the Wi-Fi driver) follows Amazon's own GPL kernel for its
MT8163 devices (github.com/amazon-oss/android_kernel_amazon_mt8163). [PROVENANCE.md](PROVENANCE.md)
lists where each part comes from.

## What works

The device tree it ships is `dts/mt8163-amazon-cronos-v4.1-display.dts`: linux-mtk's
`mt8163-amazon-cronos.dts` with the board's parts added. Each part below works on units that run
this kernel with more patches on top (an overlay, see `../README.md`); the build from this
repository alone has those parts and not the others, but has not been booted on its own yet.

| Part | State |
| --- | --- |
| The four CPU cores (`mt8163-boot.c`: the boot loader's secure monitor records the entry point and the kernel powers the core through the SPM), frequency scaling, thermal throttling (`0011`) | works |
| CPU idle with the screen on (`mt8163-sodi.c`, SODI): CPU0, the cluster and MCUSYS powered off while the display scans out | off until enabled at run time (`/sys/module/mt8163_sodi/parameters/enable`), and only with one core online |
| Serial console (UART0), eMMC, USB (device mode) | works |
| Display: the ST7701S panel, taken over from the boot loader's picture (`0012`, `0016`) | works, with brightness |
| Touch screen (Goodix GT9xx), volume buttons, privacy switch (`0009`), ambient light sensor | works |
| GPU (Mali-T720, panfrost), the JPEG encoder (mtk-jpeg) | works |
| Sound: the TAS5805M amplifier (its settings come from `tools/`), the two microphones and the playback loopback through the FPGA on SPI and its TLV320AIC3101 ADC | works, with the firmware `tools/prepare-firmware.py` prepares |
| Wi-Fi (MT7668 on SDIO, Amazon's driver, `wifi/`), as `extra/mt76x8_wlan.ko` | works; the firmware comes from the root filesystem |
| `/dev/Vcodec` (`mt8163-vcodec.ko`), the kernel side of MediaTek's AP-driven H.264 decoder and encoder libraries | the device works; the libraries are not part of this repository |
| Camera | the device tree describes it; its driver is not in this repository |

## Firmware

The drivers load firmware from the root filesystem, which this repository does not ship.
`tools/prepare-firmware.py` puts it together, from the user's own unit and public sources:

    python3 tools/prepare-firmware.py --boot <the unit's stock boot.img> \
        --bluetooth <mt7668pr2h.bin> --regulatory <dir with regulatory.db and .p7s> --output <dir>

It writes `amazon/i2s_to_spi_4ch_v208.bin` and `_v193.bin` (the microphone FPGA's bitstreams, found in
the stock boot image's kernel), `tas5805m/tas5805m_dsp_default.bin` (the amplifier's settings, built
from Amazon's `tas5805m_mono.h`, downloaded at a pinned commit and checked), the two files given, and
a `manifest.json` with their sums.

## Building

    ../build.sh cronos

The output (`../out/cronos` by default):

| File | What it is |
| --- | --- |
| `Image.gz` | the kernel |
| `cronos.dtb` | the device tree, padded to 256 KiB so the boot loader can add to it |
| `modules.tar.gz` | the modules, `lib/modules/<release>/`, ready to unpack into a root filesystem; the Wi-Fi module is in `extra/` |
| `kernel.config`, `kernel.release` | the configuration and the release string |
| `SHA256SUMS`, `manifest.json` | sums, and the manifest (`../README.md`) |

The configuration is `config/cronos.config` with `config/drivers.config`, completed by
`make olddefconfig`. The build downloads, besides the kernel, three files of Amazon's MT8163 kernel and
its Wi-Fi driver's tree, at pinned commits, checked by sha256 or git tree hash.

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
