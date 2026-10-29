# Sources

Every source the builds use, and where it comes from. [sources.json](sources.json) is the full
record: for each copied file its path at the origin, its git blob and its sha256.

The builds use only what is in this repository, plus the downloads below. A download is checked
against its sha256 before it is used. The copies are byte for byte what their origin held at the
commit given, and only the files the builds use are copied, with their own license files and notices.

    tools/check-sources.py              # are the copies as recorded? (no network)
    tools/check-sources.py --upstream   # has an origin moved on, and did the copied files change there?

The second form asks each origin over the network and only reports; it changes nothing.

## Copied

| In this repository | Origin | Commit | License |
| --- | --- | --- | --- |
| `athena/board/` | github.com/HuskerMinion/techo5, branch `main`, path `tools/linux/athena/kernel` (git tree `460e4e5ea8ae3297a231d05f25b664c82ab0d3b7`) | `d44e005b2df507bfeae4703fc3e717f34832038a` | MIT ([athena/board/LICENSE](athena/board/LICENSE)); its patches and drivers GPL-2.0, its device tree GPL-2.0 OR MIT, as their SPDX lines say |
| `third_party/amazon-mt8163/` | github.com/amazon-oss/android_kernel_amazon_mt8163, branch `lineage-18.1`: `sound/soc/codecs/tlv320aic3101.c` and `.h`, `sound/soc/codecs/tas5805m_mono.h`, `drivers/misc/mediatek/imgsensor/src/mt8163/ov02b10_mipi_raw/ov02bmipiraw_Sensor.c`, and `COPYING` | `b27e73e3b00b1184d33f1ae5aa55dc0a1e8d491f` | GPL-2.0 (the tree's `COPYING` and each file's notice) |
| `third_party/amazon-mt76x8-wifi/` | github.com/amazon-oss/android_kernel_amazon_mt76x8-wifi, branch `lineage-18.1`: `configs/cronos.config` and the files of `module/` the build compiles (git tree `0770f0e4f4848cc4c7e51a4cf4816511b6cd9df8`) | `214defc87321931c7d2d4444ba40bef56da74e6e` | GPL-2.0 (each file's notice; the tree has no license file) |

Which part of the builds uses each copy is in [athena/PROVENANCE.md](athena/PROVENANCE.md) and
[cronos/PROVENANCE.md](cronos/PROVENANCE.md).

## Downloaded, checked by sha256

These are not copied: they are large, kept by their publishers for good, and the build checks each
against its sha256.

| What | From | sha256 |
| --- | --- | --- |
| Linux 7.2.13 (athena, cronos) | cdn.kernel.org, `linux-7.2.13.tar.xz` | `08e7b0c4f2dd1971f972da274b5e589a98989390ac56acd7a1a5af922363ea6c` |
| MT7663 Wi-Fi and Bluetooth firmware, MT8183 SCP firmware, `LICENCE.mediatek` (athena) | linux-firmware, tag `20260916` | each file's, in `athena/build.sh` and `sources.json` |

The build container (`docker/Dockerfile`) starts from Debian's `debian:bookworm-slim` image and
installs the compiler and tools from Debian's packages. Neither is pinned by digest; the kernel
artifacts' sums are what pins a build.
