#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Check the sources this repository copies, against sources.json.

    tools/check-sources.py              check the copies in this repository (no network)
    tools/check-sources.py --upstream   also ask each origin whether it has changed since its commit

Offline, every copied file must be where sources.json says, with its sha256, and nothing else may be
in a copy's directory. For the downloaded sources, the sha256 in sources.json must be the one the
build script pins.

With --upstream, each copied source's origin is asked (git ls-remote) where its branch is now. If
the branch has moved, its new commit is fetched without file contents (git fetch --depth=1
--filter=blob:none, into a temporary directory) and each copied file's git blob there is compared
with the one copied: changed, removed or the same. It also checks that the pinned commit can still be
fetched, and that each download's URL still answers. It never changes anything; it only reports.

Exit status: 0 if the copies match (and, with --upstream, every origin was reachable), 1 otherwise.
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 16), b""):
            h.update(block)
    return h.hexdigest()


def check_local(manifest):
    ok = True
    for src in manifest["copied"]:
        base = os.path.join(ROOT, src["local"])
        bad = []
        for rel, want in src["files"].items():
            path = os.path.join(base, rel)
            if not os.path.isfile(path):
                bad.append("missing " + rel)
            elif sha256(path) != want["sha256"]:
                bad.append("changed " + rel)
        listed = set(src["files"])
        for dirpath, _, names in os.walk(base):
            for name in names:
                rel = os.path.relpath(os.path.join(dirpath, name), base)
                if rel not in listed:
                    bad.append("not in sources.json: " + rel)
        print("%-26s %s: %s" % (src["name"], src["local"],
                                 "%d files match" % len(listed) if not bad else "MISMATCH"))
        for b in bad:
            print("    " + b)
        ok = ok and not bad
    for item in manifest["fetched"]:
        pinned = item.get("pinned_in", [])
        if pinned and item.get("sha256"):
            for script in pinned:
                with open(os.path.join(ROOT, script)) as f:
                    found = item["sha256"] in f.read()
                print("%-26s fetched, sha256 %s in %s" % (item["name"], "pinned" if found else "NOT FOUND", script))
                ok = ok and found
        else:
            print("%-26s fetched, %s" % (item["name"], item.get("note", "not pinned by sha256")))
    return ok


def git(*args, cwd=None):
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout


def check_upstream(manifest):
    ok = True
    for src in manifest["copied"]:
        o = src["origin"]
        name = src["name"]
        try:
            refs = git("ls-remote", o["repo"], "refs/heads/" + o["branch"]).split()
        except subprocess.CalledProcessError as e:
            print("%-26s %s: not reachable (%s)" % (name, o["repo"], e.stderr.strip()))
            ok = False
            continue
        if not refs:
            print("%-26s %s: branch %s is gone" % (name, o["repo"], o["branch"]))
            ok = False
            continue
        head = refs[0]
        with tempfile.TemporaryDirectory() as tmp:
            git("init", "-q", "--bare", tmp)
            try:
                git("fetch", "-q", "--depth=1", "--filter=blob:none", o["repo"], o["commit"], cwd=tmp)
                pinned = "still fetchable"
            except subprocess.CalledProcessError:
                pinned = "NO LONGER FETCHABLE"
                ok = False
            if head == o["commit"]:
                print("%-26s %s %s: at the pinned commit %s; pinned commit %s"
                      % (name, o["repo"], o["branch"], o["commit"][:12], pinned))
                continue
            print("%-26s %s %s: moved from %s to %s; pinned commit %s"
                  % (name, o["repo"], o["branch"], o["commit"][:12], head[:12], pinned))
            try:
                git("fetch", "-q", "--depth=1", "--filter=blob:none", o["repo"], head, cwd=tmp)
            except subprocess.CalledProcessError as e:
                print("    could not fetch %s: %s" % (head[:12], e.stderr.strip()))
                ok = False
                continue
            changed = removed = 0
            for rel, want in sorted(src["files"].items()):
                out = git("ls-tree", head, "--", want["path"], cwd=tmp).split()
                if not out:
                    print("    removed there: " + want["path"])
                    removed += 1
                elif out[2] != want["blob"]:
                    print("    changed there: " + want["path"])
                    changed += 1
            print("    copied files: %d changed, %d removed, %d the same"
                  % (changed, removed, len(src["files"]) - changed - removed))
    for item in manifest["fetched"]:
        url = item.get("check_url")
        if not url:
            continue
        try:
            # The first byte only: some servers refuse HEAD, or a client that does not name itself.
            req = urllib.request.Request(url, headers={"Range": "bytes=0-0", "User-Agent": "check-sources.py"})
            with urllib.request.urlopen(req, timeout=30) as r:
                status = r.status
            print("%-26s %s: answers (%d)" % (item["name"], url, status))
        except Exception as e:  # report and go on
            print("%-26s %s: NOT REACHABLE (%s)" % (item["name"], url, e))
            ok = False
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--upstream", action="store_true", help="also check each origin over the network")
    a = ap.parse_args()
    with open(os.path.join(ROOT, "sources.json")) as f:
        manifest = json.load(f)
    ok = check_local(manifest)
    if a.upstream:
        ok = check_upstream(manifest) and ok
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
