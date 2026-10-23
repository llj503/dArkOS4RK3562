#!/usr/bin/env bash
# Single build entry point for the two RK3562 dArkOS consoles.
#
# Artifact mode (default, no root needed):
#   ./build_image.sh                      # both consoles
#   ./build_image.sh ngp45ht pocketais    # explicit selection
#   ./build_image.sh ngp45ht --outdir dist
#
# Produces:
#   <outdir>/DarkOS-<device>-p3.img       99 MiB FAT boot partition
#   <outdir>/update-darkos-<device>.tar   rootfs overlay
#   <outdir>/SHA256SUMS.txt
#
# Full-image mode (Linux, root, one device):
#   sudo ./build_image.sh pocketais --base base.img
#   sudo ./build_image.sh ngp45ht --base base.img --output out.img
#
# The base image is copied first and only the copy is modified.  p3 is written
# at 16 MiB; the overlay is extracted into the BTRFS p4 at
# 116 MiB.  Pocket AIS additionally has sectors 64-32767 zeroed and its GPT
# repaired (Rockchip p1/p2 types, p3 bootable flag, both CRCs).
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEVICES=()
OUTDIR="$ROOT/out"
BASE=""
OUTPUT=""

usage() {
    sed -n "2,21p" "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage 0 ;;
        --base) BASE=${2:?--base needs an image path}; shift 2 ;;
        --output) OUTPUT=${2:?--output needs a path}; shift 2 ;;
        --outdir) OUTDIR=${2:?--outdir needs a path}; shift 2 ;;
        -*) echo "unknown option: $1" >&2; usage 1 ;;
        *) DEVICES+=("$1"); shift ;;
    esac
done

[ "${#DEVICES[@]}" -gt 0 ] || DEVICES=(ngp45ht pocketais)
for dev in "${DEVICES[@]}"; do
    case "$dev" in
        ngp45ht|pocketais) ;;
        *) echo "unknown device: $dev" >&2; exit 2 ;;
    esac
done

if [ -n "$BASE" ] && [ "${#DEVICES[@]}" -ne 1 ]; then
    echo "--base builds one device at a time (got: ${DEVICES[*]})" >&2
    exit 2
fi

mkdir -p "$OUTDIR"

echo "== build artifacts =="
BUILT=()
for dev in "${DEVICES[@]}"; do
    p3="$OUTDIR/DarkOS-${dev}-p3.img"
    overlay="$OUTDIR/update-darkos-${dev}.tar"
    "$ROOT/scripts/build_boot.sh" "$dev" "$p3"
    python3 "$ROOT/scripts/build_overlay.py" "$dev" "$overlay"
    BUILT+=("DarkOS-${dev}-p3.img" "update-darkos-${dev}.tar")
done

(
    cd "$OUTDIR"
    sha256sum "${BUILT[@]}" > SHA256SUMS.txt
    echo "== checksums =="
    cat SHA256SUMS.txt
)

if [ -z "$BASE" ]; then
    echo "== done: $OUTDIR =="
    exit 0
fi

DEV=${DEVICES[0]}
[ -f "$BASE" ] || { echo "base image not found: $BASE" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "full-image mode needs root (use sudo)" >&2; exit 1; }
for c in losetup mount tar; do
    command -v "$c" >/dev/null || { echo "missing tool: $c" >&2; exit 1; }
done

P3="$OUTDIR/DarkOS-${DEV}-p3.img"
OVERLAY="$OUTDIR/update-darkos-${DEV}.tar"
OUT=${OUTPUT:-"$OUTDIR/DarkOS-${DEV}.img"}
[ "$BASE" != "$OUT" ] || { echo "output must differ from the base image" >&2; exit 1; }

WORK=$(mktemp -d)
MNT="$WORK/p4"
mkdir -p "$MNT"
cleanup() {
    mountpoint -q "$MNT" 2>/dev/null && umount "$MNT" 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

echo "== full image: $DEV =="
echo "copy: $BASE -> $OUT"
cp --sparse=always "$BASE" "$OUT"

echo "write p3 at 16 MiB"
dd if="$P3" of="$OUT" bs=1M seek=16 conv=notrunc status=progress

if [ "$DEV" = pocketais ]; then
    echo "zero idbloader/p1/p2 and repair GPT"
    dd if=/dev/zero of="$OUT" bs=512 seek=64 count=32704 conv=notrunc status=none
    python3 "$ROOT/scripts/fix_gpt.py" "$OUT"
fi

echo "extract rootfs overlay into p4"
mount -t btrfs -o loop,rw,offset=121634816 "$OUT" "$MNT"
tar --numeric-owner -xf "$OVERLAY" -C "$MNT"
sync
umount "$MNT"

echo "image: $OUT"
sha256sum "$OUT"
