#!/usr/bin/env python3
"""Build a rootfs overlay tar with explicit, platform-independent modes.

Windows cannot represent the executable bit on a mounted repo, so a plain
`tar` there records 0777 for every file.  This walks the two overlay trees and
sets modes from the content (shebang/ELF -> 0755), keeping config files 0644
and the two ark-writable panel files 0664/0666.

Usage: make_update_tar.py <common-dir> <device-dir> <out.tar>
"""
import os
import sys
import tarfile

MODE_OVERRIDES = {
    "opt/ngp-panel/panel.conf": 0o664,
    "opt/ngp-panel/led.conf": 0o666,
}


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
            info.mtime = int(os.stat(root).st_mtime)
            info.uid = info.gid = 0
            info.uname = info.gname = "root"
            tar.addfile(info)
        for name in files:
            path = os.path.join(root, name)
            rel = os.path.relpath(path, base)
            info = tar.gettarinfo(path, arcname=rel.replace(os.sep, "/"))
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
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    common, dev, out = sys.argv[1:]
    if not os.path.isdir(common) or not os.path.isdir(dev):
        raise SystemExit(f"missing overlay dir: {common} or {dev}")
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    if os.path.exists(out):
        os.unlink(out)
    with tarfile.open(out, "w", format=tarfile.GNU_FORMAT) as tar:
        add_tree(tar, common)
        add_tree(tar, dev)
    print(f"rootfs overlay: {out} ({os.path.getsize(out)} bytes)")


if __name__ == "__main__":
    main()
