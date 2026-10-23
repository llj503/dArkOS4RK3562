#!/usr/bin/env python3
"""Build the rootfs overlay tar for one RK3562 console.

The archive is extracted at / on the target rootfs and contains the common
overlay plus the device overlay (device files win).  Modes are content-based so
the result is identical on Windows and Linux; entry mtimes are fixed, so
repeated builds are byte-identical.

Usage: scripts/build_overlay.py <ngp45ht|pocketais> [rootfs.tar]
"""
import hashlib
import os
import sys
import tarfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEVICES = ("ngp45ht", "pocketais")
MODE_OVERRIDES = {
    "opt/ngp-panel/panel.conf": 0o664,
    "opt/ngp-panel/led.conf": 0o666,
}

# Reproducible archives: source mtimes differ between a Windows checkout, CI and
# repeated builds.  Honour SOURCE_DATE_EPOCH when set, otherwise use a fixed date.
EPOCH = int(os.environ.get("SOURCE_DATE_EPOCH", "1767225600"))


def mode_for(rel, path):
    rel = rel.replace(os.sep, "/")
    if rel in MODE_OVERRIDES:
        return MODE_OVERRIDES[rel]
    with open(path, "rb") as fh:
        head = fh.read(4)
    if head.startswith(b"#!") or head == b"\x7fELF":
        return 0o755
    return 0o644


def add_tree(tar, base):
    base = os.path.abspath(base)
    for root, dirs, files in os.walk(base):
        dirs.sort()
        files.sort()
        rel_root = os.path.relpath(root, base)
        if rel_root != ".":
            info = tarfile.TarInfo(rel_root.replace(os.sep, "/"))
            info.type = tarfile.DIRTYPE
            info.mode = 0o755
            info.mtime = EPOCH
            info.uid = info.gid = 0
            info.uname = info.gname = "root"
            tar.addfile(info)
        for name in files:
            path = os.path.join(root, name)
            rel = os.path.relpath(path, base)
            info = tar.gettarinfo(path, arcname=rel.replace(os.sep, "/"))
            info.mtime = EPOCH
            info.uid = info.gid = 0
            info.uname = info.gname = "root"
            if info.issym() or info.islnk():
                tar.addfile(info)
            elif info.isfile():
                info.mode = mode_for(rel, path)
                with open(path, "rb") as fh:
                    tar.addfile(info, fh)
            else:
                raise SystemExit(f"unsupported file type: {path}")


def main():
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        raise SystemExit(__doc__)
    dev = sys.argv[1]
    if dev not in DEVICES:
        raise SystemExit(f"unknown device: {dev} (choose from {', '.join(DEVICES)})")
    out = sys.argv[2] if len(sys.argv) == 3 else os.path.join(
        ROOT, "out", f"rootfs-{dev}.tar")

    common = os.path.join(ROOT, "rootfs", "dArkOS", "common")
    device = os.path.join(ROOT, "rootfs", "dArkOS", dev)
    for d in (common, device):
        if not os.path.isdir(d):
            raise SystemExit(f"missing overlay dir: {d}")

    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    if os.path.exists(out):
        os.unlink(out)
    with tarfile.open(out, "w", format=tarfile.GNU_FORMAT) as tar:
        add_tree(tar, common)
        add_tree(tar, device)

    digest = hashlib.sha256()
    with open(out, "rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    print(f"overlay {dev}: {out} ({os.path.getsize(out)} bytes)")
    print(f"{digest.hexdigest()}  {out}")


if __name__ == "__main__":
    main()
