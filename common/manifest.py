#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Write manifest.json for a build's artifacts.

    manifest.py DEVICE KERNEL_VERSION KERNEL_SHA256 DIR FILE...

The manifest names the device, the kernel.org release and its tarball's sha256, the kernel release
string (kernel.release in DIR), the commits the build came from (the environment's SOURCE_COMMIT and
OVERLAY_COMMIT, which ../build.sh sets) and every artifact with its size and sha256. A consumer
checks the files against it, and can pin a build by the manifest's own sha256.
"""
import hashlib
import json
import os
import sys


def main(argv):
    if len(argv) < 6:
        sys.exit(__doc__)
    device, kver, ksha, d = argv[1:5]
    files = {}
    for name in argv[5:]:
        data = open(os.path.join(d, name), "rb").read()
        files[name] = {"size": len(data), "sha256": hashlib.sha256(data).hexdigest()}
    manifest = {
        "device": device,
        "linux": {"version": kver, "tarball_sha256": ksha},
        "kernel_release": open(os.path.join(d, "kernel.release")).read().strip(),
        "source_commit": os.environ.get("SOURCE_COMMIT", ""),
        "overlay_commit": os.environ.get("OVERLAY_COMMIT", ""),
        "files": files,
    }
    with open(os.path.join(d, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
        f.write("\n")
    print("manifest.json: %s, %s, %d files" % (device, manifest["kernel_release"], len(files)))


if __name__ == "__main__":
    main(sys.argv)
