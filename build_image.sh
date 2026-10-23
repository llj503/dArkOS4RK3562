#!/usr/bin/env bash
# Apply a device boot bundle and (optionally) the rootfs overlay to a base
# dArkOS RK3562 image.  The base images are NOT in this repository.
#
# Usage:
#   sudo ./build_image.sh <base.img> <ngp45ht|pocketais> [--rootfs] [out.img]
#
#   --rootfs  also mount p4 (BTRFS) and extract update-darkos-<device>.tar
#
# The p3/p4 offsets match both the NGP45HT and Pocket AIS RK3562 layouts:
#   p3: 16 MiB, 99 MiB FAT
#   p4: 116 MiB, BTRFS
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE=${1:?usage: build_image.sh <base.img> <ngp45ht|pocketais> [--rootfs] [out.img]}
DEV=${2:?usage: build_image.sh <base.img> <ngp45ht|pocketais> [--rootfs] [out.img]}
shift 2

ROOTFS=0
OUT=""
while [ $# -gt 0 ]; do
    case "$1" in
        --rootfs) ROOTFS=1 ;;
        *) OUT=$1 ;;
    esac
    shift
done

case "$DEV" in
    ngp45ht|pocketais) ;;
    *) echo "unknown device: $DEV" >&2; exit 2 ;;
esac
[ -f "$BASE" ] || { echo "base image not found: $BASE" >&2; exit 1; }
[ -n "$OUT" ] || OUT="${BASE%.img}-${DEV}.img"
[ "$BASE" != "$OUT" ] || { echo "output must differ from base image" >&2; exit 1; }

P3_OFFSET_MIB=16
P4_OFFSET=$((237568 * 512))
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "== boot bundle =="
"$ROOT/scripts/build_boot_bundle.sh" "$DEV" "$WORK/p3.img"

echo "== copy base image =="
cp --sparse=always "$BASE" "$OUT"
dd if="$WORK/p3.img" of="$OUT" bs=1M seek="$P3_OFFSET_MIB" conv=notrunc status=progress

if [ "$DEV" = pocketais ]; then
    echo "== Pocket AIS: zero TF idbloader/p1/p2 and fix GPT =="
    dd if=/dev/zero of="$OUT" bs=512 seek=64 count=32704 conv=notrunc status=none
    python3 "$ROOT/scripts/fix_gpt_20261020.py" "$OUT"
fi

if [ "$ROOTFS" -eq 1 ]; then
    echo "== rootfs overlay =="
    "$ROOT/scripts/build_update_tar.sh" "$DEV" "$WORK/rootfs.tar"
    MNT="$WORK/p4"
    mkdir -p "$MNT"
    mount -t btrfs -o loop,rw,offset="$P4_OFFSET" "$OUT" "$MNT"
    trap 'umount "$MNT" 2>/dev/null || true; rm -rf "$WORK"' EXIT
    tar --numeric-owner -xf "$WORK/rootfs.tar" -C "$MNT"
    sync
    umount "$MNT"
    trap 'rm -rf "$WORK"' EXIT
fi

sync
echo "image: $OUT ($(stat -c %s "$OUT") bytes)"
sha256sum "$OUT"
