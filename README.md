# linux-amazon-echo

Build scripts and patches that turn a kernel.org Linux release into a kernel for two Amazon Echo
Show smart displays:

| Device | Code name | SoC (system on a chip) | Directory |
| --- | --- | --- | --- |
| Echo Show 8, 2nd generation (2021) | athena | MediaTek MT8183 | [athena/](athena/README.md) |
| Echo Show 5, 2nd generation (2021) | cronos | MediaTek MT8163 | [cronos/](cronos/README.md) |

Both build Linux 7.2.13 from the kernel.org tarball, checked against its sha256. A build produces
versioned *artifacts*: the parts of a boot image (the compressed kernel `Image.gz`, the device tree
blob, the modules or the firmware ramdisk) and a `manifest.json` that lists them with their sizes and
sha256 sums. What you do with them (pack them into a boot image for your unit's boot loader, put the
modules into a root filesystem) is up to the system you build on top.

This project is not affiliated with, endorsed by or sponsored by Amazon. Amazon, Echo and Echo Show
are trademarks of Amazon.com, Inc. or its affiliates. MediaTek is a trademark of MediaTek Inc.

## What you need

- A unit whose boot loader starts a boot image you built. A stock unit does not: it only starts
  images Amazon signed. How to get there is not covered here.
- Docker. The build runs in an arm64 Debian 12 container (`docker/Dockerfile`), natively on an arm64
  host (an Apple silicon Mac, for example) and under emulation elsewhere, which is much slower.
- About 4 GB of disk for each device's kernel tree. It is kept in a Docker volume, not on the host.
- A network connection the first time: the kernel tarball (about 160 MB); for athena, a few firmware
  files from linux-firmware and the board files from the TECHO5 project; for cronos, a few files of
  Amazon's GPL MT8163 kernel and its MT7668 Wi-Fi driver. Each is checked against its sha256 sum or
  git tree hash.

## Building

    ./build.sh athena          # artifacts in out/athena
    ./build.sh cronos          # artifacts in out/cronos

The first run builds the container image (`linux-amazon-echo-build`) and creates the volume
(`linux-amazon-echo-src`). A build takes 10 to 30 minutes on a recent arm64 machine. Each run starts
from a fresh kernel tree; `KTREE=/src/<device>/linux-7.2.13` reuses the tree of the run before, which
only rebuilds what changed.

Settings, as environment variables: `BUILD_IMAGE` and `VOLUME` choose another container image or
volume, `WORK` the work directory in the volume, `CACHE` where downloads are kept, `JOBS` the number
of parallel jobs, and `PANEL` and `MCDI_CPUS` the Echo Show 8's panel and its CPU idle states (see
[athena/README.md](athena/README.md)).

## Artifacts

| Device | Files |
| --- | --- |
| athena | `Image.gz`, `athena.dtb`, `ramdisk.cpio.gz` (firmware only), `boot-athena.img` (all three packed for the boot loader), `kernel.config`, `kernel.release`, `config-dropped.txt` |
| cronos | `Image.gz`, `cronos.dtb`, `modules.tar.gz` (`lib/modules/<release>`), `kernel.config`, `kernel.release` |

Every output directory also has `SHA256SUMS` and `manifest.json`. The manifest names the device, the
Linux version and its tarball's sha256, the kernel release string (what `uname -r` prints), the commit
of this repository the build came from, and every file with its size and sha256. A system built on
these kernels can pin a kernel by those sums.

A build is reproducible: the build stamp (`uname -v`: user, host, time, build number) is fixed in
each device's `build.sh`, and the same commit built in the same container image gives the same bytes.

## How a device is built

Each device directory has the same parts:

- `build.sh`: fetches the kernel, applies the series, configures and builds the kernel, and writes the
  artifacts. It runs inside the container.
- `series`: the patch steps, one shell command a line, in order.
- `patches/`: the patches and the scripts that apply them. Most are small Python scripts that find an
  exact piece of a kernel source file and replace it, and stop if it is not there, so a kernel update
  that moves the code fails loudly instead of building something different.
- the configuration: athena starts from a configuration and changes it with `scripts/config`
  arguments (`athena/config`); cronos has a whole configuration (`cronos/config/cronos.config`).
- `PROVENANCE.md`: where each patch comes from.

## Overlays

An *overlay* is a directory that adds to a build without changing this repository: more patches, more
configuration and steps of its own, and its own build identity. Set `OVERLAY` to it:

    OVERLAY=/path/to/overlay ./build.sh athena

`<device>/build.sh` then sources `<overlay>/<device>/overlay.sh`, which may set:

| Variable or function | Meaning |
| --- | --- |
| `SERIES` | a series file to use instead of this one; it can run this repository's steps (`$PUB/...`) and the overlay's (`$OVL/...`) in any order |
| `CONFIG_FRAGMENTS` | more configuration: `scripts/config` arguments for athena, configuration lines for cronos |
| `WANT_FILES` | (athena) more lines the final `.config` must have |
| `LOCALVERSION`, `KBUILD_BUILD_USER`, `KBUILD_BUILD_HOST`, `KBUILD_BUILD_TIMESTAMP`, `KBUILD_BUILD_VERSION` | the release string's suffix and the build stamp |
| `ramdisk_hook` | (athena) a function run on the staged ramdisk firmware |
| `CPUIDLE` | (athena) set to leave `cpuidle.off=1` off the kernel command line |
| `DTB_NAME` | (cronos) the device tree to ship, from the tree's `arch/arm64/boot/dts/mediatek` |
| `modules_hook` | (cronos) a function run on the installed modules before they are packed; the default builds the Wi-Fi module into them (`wifi_module`), which an overlay's own should call too |

The overlay is mounted read-only at `/overlay` in the container. `PASS_ENV` names more environment
variables `build.sh` passes into the container, for the overlay's own settings.

## Licenses

The patches, the drivers and the device trees are under the licenses their files state, GPL-2.0 for
everything that goes into the kernel (see [COPYING](COPYING)); a device tree may also be MIT. The build
scripts are MIT ([LICENSE](LICENSE)). The athena build fetches its board files from the TECHO5
project (github.com/HuskerMinion/techo5, MIT) at a pinned commit; they are not in this repository
(see [athena/README.md](athena/README.md), "The board files"). The cronos build fetches the files of
Amazon's GPL kernels it ports, at pinned commits (see [cronos/PROVENANCE.md](cronos/PROVENANCE.md)). The
firmware files the athena build downloads are MediaTek's, under its license in linux-firmware
(`LICENCE.mediatek`), and go into the ramdisk as separate files.
