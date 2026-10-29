#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Prepare the Echo Show 5's firmware files for a root filesystem, from the user's own unit and from
public sources, without adding any binary firmware to this repository: the microphone FPGA's
bitstreams (out of the unit's own stock boot image), the amplifier's settings (built from Amazon's GPL
tas5805m_mono.h), and the Bluetooth firmware and the regulatory database the user supplies."""
import argparse
import hashlib
import importlib.util
import json
import urllib.request
from pathlib import Path

# sound/soc/codecs/tas5805m_mono.h of github.com/amazon-oss/android_kernel_amazon_mt8163 (../PROVENANCE.md)
TAS5805M_URL = ('https://raw.githubusercontent.com/amazon-oss/android_kernel_amazon_mt8163/'
                'b27e73e3b00b1184d33f1ae5aa55dc0a1e8d491f/sound/soc/codecs/tas5805m_mono.h')
TAS5805M_SHA256 = '9eec16003ca73b1a5295c520cda2b7d8551872e36a263145487c05986f9332aa'


def load(name):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--boot', required=True, type=Path, help='vendor boot image with FPGA firmware')
    ap.add_argument('--bluetooth', required=True, type=Path, help='locally supplied mt7668pr2h.bin')
    ap.add_argument('--regulatory', required=True, type=Path, help='directory with regulatory.db and its signature')
    ap.add_argument('--tas5805m', type=Path,
                    help='a local copy of tas5805m_mono.h (default: download it from the pinned commit)')
    ap.add_argument('--output', type=Path, required=True,
                    help='where to write them, as lib/firmware is laid out')
    a = ap.parse_args()
    files = {'amazon/' + name: data for name, data in load('extract-fpga-fw').extract(a.boot.read_bytes()).items()}
    files['mediatek/mt7668pr2h.bin'] = a.bluetooth.read_bytes()
    for name in ('regulatory.db', 'regulatory.db.p7s'):
        files[name] = (a.regulatory / name).read_bytes()
    if a.tas5805m:
        source = a.tas5805m.read_bytes()
    else:
        with urllib.request.urlopen(TAS5805M_URL) as r:
            source = r.read()
    if hashlib.sha256(source).hexdigest() != TAS5805M_SHA256:
        raise ValueError('tas5805m_mono.h is not the pinned file')
    files['tas5805m/tas5805m_dsp_default.bin'] = load('build-tas5805m-cfg').build(source.decode())
    if any(not data for data in files.values()):
        raise ValueError('Firmware inputs must not be empty')
    for name, data in files.items():
        path = a.output / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    manifest = {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}
    (a.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Prepared local firmware in', a.output)


if __name__ == '__main__':
    main()
