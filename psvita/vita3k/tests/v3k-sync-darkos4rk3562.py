#!/usr/bin/env python3
"""Sync Vita3K port sources into the dArkOS4RK3562 checkout.

Creates psvita/vita3k/ as the single source directory ("供调用") and refreshes
the rootfs diff layer from it. Run before scripts/sync_image.sh (which calls
psvita/vita3k/install.sh automatically).

Usage: python3 v3k-sync-darkos4rk3562.py [checkout] [workspace]
Defaults: /tmp/darkos4rk3562 and the workspace holding this script.
"""
import os
import pathlib
import shutil
import sys

WORK = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else
                    pathlib.Path(__file__).resolve().parents[2])
REPO = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                    "/tmp/darkos4rk3562")
SRC = REPO / "psvita" / "vita3k"
RF = REPO / "rootfs"

WRAPPER = """#!/bin/bash
# /usr/local/bin/vita3k - thin entry to the bundle's own launcher.
# Full chain: ES -> /usr/local/bin/psv.sh -> /usr/local/bin/vita3k
#             -> /opt/vita3k/vita3k.sh -> Vita3K
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BUNDLE=/opt/vita3k
if [ ! -x "$BUNDLE/vita3k.sh" ]; then
    echo "vita3k: $BUNDLE/vita3k.sh is missing" >&2
    exit 1
fi
exec "$BUNDLE/vita3k.sh" "$@"
"""

PATHS = """# Source this from any build/deploy script that needs Vita3K paths.
VITA3K_OPT=/opt/vita3k
VITA3K_BIN=/usr/local/bin
# ROM partition: /roms or /roms2, data lives in the psvita game folder.
VITA3K_DATA=${VITA3K_DATA:-/roms/psvita/Vita3k}
"""

INSTALL = """#!/bin/bash
# Refresh the rootfs diff layer from psvita/vita3k/ (called by sync_image.sh).
# Override with VITA3K_DATA=/roms2/psvita/Vita3k for the second ROM partition.
set -euo pipefail
D=${1:-$(cd "$(dirname "$0")/../.." && pwd)}
S=$(cd "$(dirname "$0")" && pwd)
DATA=${VITA3K_DATA:-/roms/psvita/Vita3k}
. "$S/vita3k-paths.sh"

copy() { # src dst mode [sed-data-path]
    mkdir -p "$(dirname "$2")"
    if [ "${3:-}" = "text" ]; then
        sed "s|/roms/psvita/Vita3k|$DATA|g" "$1" > "$2"
    else
        cp "$1" "$2"
    fi
    chmod "$4" "$2"
}

echo "== Vita3K: psvita/vita3k -> rootfs (data=$DATA) =="
for f in psv.sh vita3k-pad.py psvita-lang.py psvita-option.py console-detect; do
    copy "$S/$f" "$D/rootfs/usr/local/bin/$f" text 755
done
copy "$S/vita3k" "$D/rootfs/usr/local/bin/vita3k" text 755
copy "$S/vita3k.sh" "$D/rootfs/opt/vita3k/vita3k.sh" text 755
copy "$S/config-template.yml" "$D/rootfs/opt/vita3k/config-template.yml" text 644
for f in BUILD-INFO.txt VkLayer_window_system_integration.json \
         libVkLayer_window_system_integration.so; do
    copy "$S/wsi/$f" "$D/rootfs/opt/vita3k-wsi/$f" bin 644
done
for f in theme.xml system.png background_icon.png; do
    copy "$S/theme/$f" "$D/rootfs/tempthemes/es-theme-nes-box/psvita/$f" bin 644
done
# ES entry must point at /usr/local/bin/psv.sh
CFG="$D/rootfs/etc/emulationstation/es_systems.cfg"
if [ -f "$CFG" ] && grep -q '<name>psvita</name>' "$CFG"; then
    # Only fix the psvita command; never touch other systems' <command>.
    sed -i 's|<command>/usr/local/bin/psv.sh %ROM%</command>|<command>/usr/local/bin/psv.sh %ROM%</command>|' "$CFG"
else
    python3 "$S/patch_es_vita.py" "$CFG"
    sed -i 's|/usr/local/bin/psv.sh|/usr/local/bin/psv.sh|' "$CFG"
fi
# /opt/vita3k/portable is created at first boot by the launcher; keep the
# binary bundle itself untouched (release asset, already in rootfs/opt/vita3k).
echo "== Vita3K: done. Run scripts/sync_image.sh to write the image. =="
"""

BUILD = """#!/bin/bash
# Rebuild the two Wayland tools on the device (arm64, needs libwayland-dev,
# libfreetype-dev, libpng-dev, wayland-scanner). Override VITA3K_DATA for /roms2.
set -euo pipefail
S=$(cd "$(dirname "$0")" && pwd)
DATA=${VITA3K_DATA:-/roms/psvita/Vita3k}
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
for f in vita3k-osd-wl.c vita3k-frontend-wl.c xdg-shell.xml; do
    cp "$S/$f" "$T/"
done
sed -i "s|/roms/psvita/Vita3k|$DATA|g" "$T"/*.c
cd "$T"
wayland-scanner private-code xdg-shell.xml xdg-shell-protocol.c
wayland-scanner client-header xdg-shell.xml xdg-shell-client-protocol.h
CFLAGS="-O2 -Wall -I."
LIBS="-lrt -lm"
gcc $CFLAGS -o vita3k-osd vita3k-osd-wl.c xdg-shell-protocol.c \\
    $(pkg-config --cflags --libs wayland-client freetype2) $LIBS
gcc $CFLAGS -o vita3k-frontend vita3k-frontend-wl.c xdg-shell-protocol.c \\
    $(pkg-config --cflags --libs wayland-client freetype2 libpng) $LIBS
install -m 755 vita3k-osd /usr/local/bin/vita3k-osd
install -m 755 vita3k-frontend /usr/local/bin/vita3k-frontend
echo "built; data root = $DATA"
"""

SYNC_HOOK = """
# Vita3K 等独立模拟器: 先从 psvita/vita3k 源目录刷新 rootfs 差异层
if [[ -x "$D/psvita/vita3k/install.sh" ]]; then
  echo "== 同步 Vita3K 源目录 -> rootfs"
  "$D/psvita/vita3k/install.sh" "$D"
fi
"""


def norm(text: str) -> str:
    return text.replace("\r\n", "\n")


def paths(text: str) -> str:
    """Canonical device layout: /opt/vita3k + /usr/local/bin + ROM game folder.

    This image keeps Vita3K data in /roms/psvita/Vita3k (a folder under the
    psvita game folder); the other port used /roms/psvita/Vita3k, so map it here.
    """
    t = norm(text)
    t = t.replace("/roms/psvita/Vita3k", "/roms/psvita/Vita3k")
    t = t.replace("/usr/local/bin/psv.sh", "/usr/local/bin/psv.sh")
    t = t.replace("psv.sh", "psv.sh")
    return t


def launcher(text: str) -> str:
    """Route the ES launcher through /usr/local/bin/vita3k."""
    t = paths(text)
    if 'if [ -n "${VITA3K_DATA:-}" ]; then' not in t:
        t = t.replace('DATA=/roms/psvita/Vita3k\n', '''if [ -n "${VITA3K_DATA:-}" ]; then
    DATA=$VITA3K_DATA
elif [ -d /roms2/psvita ]; then
    DATA=/roms2/psvita/Vita3k
else
    DATA=/roms/psvita/Vita3k
fi
''', 1)
    t = t.replace('if [ ! -x "$BUNDLE/vita3k.sh" ]; then',
                  'if [ ! -x /usr/local/bin/vita3k ]; then')
    t = t.replace('echo "psvita: $BUNDLE/vita3k.sh is missing" >&2',
                  'echo "psvita: /usr/local/bin/vita3k is missing" >&2')
    t = t.replace('"$BUNDLE/vita3k.sh" --firmware "$_path"',
                  '/usr/local/bin/vita3k --firmware "$_path"')
    t = t.replace('"$BUNDLE/vita3k.sh" "${ARGS[@]}"',
                  '/usr/local/bin/vita3k "${ARGS[@]}"')
    t = t.replace('# Installed as /usr/local/bin/psv.sh (dArkOS launcher naming); bundle in /opt/vita3k',
                  '# Installed as /usr/local/bin/psv.sh; chain continues via /usr/local/bin/vita3k')
    return t


def put(path: pathlib.Path, text: str, mode: int = 0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    data = norm(text).encode("utf-8")
    if path.exists() and path.read_bytes() == data:
        return False
    path.write_bytes(data)
    os.chmod(path, mode)
    return True


def copy(src: pathlib.Path, dst: pathlib.Path, transform=None, mode=0o644):
    if not src.exists():
        print("  MISSING SOURCE", src)
        return False
    data = src.read_bytes()
    if transform:
        text = transform(data.decode("utf-8", errors="replace"))
        return put(dst, text, mode)
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() and dst.read_bytes() == data:
        return False
    dst.write_bytes(data)
    os.chmod(dst, mode)
    return True


def main():
    if not (REPO / ".git").is_dir():
        raise SystemExit(f"not a git checkout: {REPO}")
    changed = []

    # 1. adapted sources already in this repo
    adapted = {
        "rootfs/usr/local/bin/psv.sh": ("psv.sh", launcher, 0o755),
        "rootfs/usr/local/bin/vita3k-pad.py": ("vita3k-pad.py", paths, 0o755),
        "rootfs/usr/local/bin/psvita-lang.py": ("psvita-lang.py", paths, 0o755),
        "rootfs/usr/local/bin/psvita-option.py": ("psvita-option.py", paths, 0o755),
        "rootfs/usr/local/bin/console-detect": ("console-detect", paths, 0o755),
        "tools/vita3k-osd-wl.c": ("vita3k-osd-wl.c", paths, 0o644),
        "rootfs/opt/vita3k/vita3k.sh": ("vita3k.sh", paths, 0o755),
        "rootfs/opt/vita3k/config-template.yml": ("config-template.yml", paths, 0o644),
    }
    for rel, (name, fn, mode) in adapted.items():
        src = REPO / rel
        if not src.exists():
            # tools/vita3k-osd-wl.c is removed after the first sync; the
            # generated psvita/vita3k/ copy is already canonical.
            if not (SRC / name).exists():
                print("  MISSING SOURCE", src)
            continue
        if copy(src, SRC / name, fn, mode):
            changed.append("psvita/vita3k/" + name)

    # 2. sources missing from this repo, taken from the port workspace
    extra = [
        "scripts/vita3k-frontend-wl.c",
        "scripts/install_vita3k.sh",
        "scripts/install_vita3k_wsi.sh",
        "scripts/package_vita3k.sh",
        "scripts/patch_es_vita.py",
        "scripts/patch_vita3k.py",
        "scripts/make_psvita_theme.py",
    ]
    for rel in extra:
        name = pathlib.Path(rel).name
        if copy(WORK / rel, SRC / name, paths, 0o755 if rel.endswith(".sh") else 0o644):
            changed.append("psvita/vita3k/" + name)
    if copy(WORK / "packages" / "xdg-shell.xml", SRC / "xdg-shell.xml"):
        changed.append("psvita/vita3k/xdg-shell.xml")

    # 3. WSI layer + ES theme (small binaries, keep the source dir self-contained)
    for name in ("BUILD-INFO.txt", "VkLayer_window_system_integration.json",
                 "libVkLayer_window_system_integration.so"):
        if copy(REPO / "rootfs/opt/vita3k-wsi" / name, SRC / "wsi" / name):
            changed.append("psvita/vita3k/wsi/" + name)
    for name in ("theme.xml", "system.png", "background_icon.png"):
        if copy(REPO / "rootfs/tempthemes/es-theme-nes-box/psvita" / name,
                SRC / "theme" / name):
            changed.append("psvita/vita3k/theme/" + name)

    # 4. reusable deploy/verify scripts
    for src in sorted((WORK / "scripts" / "tests").glob("*.py")):
        # Pushes to the other repo (dArkOS-PokectAis); do not ship it here.
        if src.name == "v3k-github-sync.py":
            continue
        if copy(src, SRC / "tests" / src.name, paths, 0o644):
            changed.append("psvita/vita3k/tests/" + src.name)

    # 5. new entry points
    for name, text, mode in (("vita3k", WRAPPER, 0o755),
                             ("vita3k-paths.sh", PATHS, 0o644),
                             ("install.sh", INSTALL, 0o755),
                             ("build.sh", BUILD, 0o755),
                             (".gitattributes",
                              "* text eol=lf\n*.png binary\n*.so binary\n", 0o644)):
        if put(SRC / name, text, mode):
            changed.append("psvita/vita3k/" + name)

    # 6. refresh the rootfs diff layer so the image works even without install.sh
    for name in ("psv.sh", "vita3k-pad.py", "psvita-lang.py",
                 "psvita-option.py", "console-detect"):
        if copy(SRC / name, RF / "usr/local/bin" / name, None, 0o755):
            changed.append("rootfs/usr/local/bin/" + name)
    if copy(SRC / "vita3k", RF / "usr/local/bin" / "vita3k", None, 0o755):
        changed.append("rootfs/usr/local/bin/vita3k")
    # ES entry: /usr/local/bin/psv.sh and extension without .sh cards
    cfg = RF / "etc/emulationstation/es_systems.cfg"
    if cfg.exists():
        t = cfg.read_text(encoding="utf-8")
        t2 = t.replace("<command>/usr/local/bin/psv.sh %ROM%</command>",
                       "<command>/usr/local/bin/psv.sh %ROM%</command>")
        t2 = t2.replace(".vpk .VPK .zip .ZIP .sh .SH",
                        ".vpk .VPK .zip .ZIP")
        if put(cfg, t2):
            changed.append("rootfs/etc/emulationstation/es_systems.cfg")

    # 7. build hook in sync_image.sh
    sync = REPO / "scripts" / "sync_image.sh"
    if sync.exists():
        t = sync.read_text(encoding="utf-8")
        anchor = 'echo "== 刷写开源 uboot (原厂 uboot 无法引导我们的内核)"'
        if "psvita/vita3k/install.sh" not in t and anchor in t:
            t = t.replace(anchor, SYNC_HOOK.strip() + "\n" + anchor, 1)
            if put(sync, t, 0o755):
                changed.append("scripts/sync_image.sh")

    # 8. the old scattered source file is now in psvita/vita3k
    old = REPO / "tools" / "vita3k-osd-wl.c"
    if old.exists():
        old.unlink()
        changed.append("tools/vita3k-osd-wl.c (removed)")

    print(f"CHANGED {len(changed)} files")
    for p in changed:
        print(" ", p)


if __name__ == "__main__":
    main()
