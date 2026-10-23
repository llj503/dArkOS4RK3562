#!/usr/bin/env bash
# Build a complete, flashable dArkOS RK3562 system image.
#
# Usage:
#   sudo ./build_image.sh <ngp45ht|pocketais> --base BASE.img [--output OUT.img]
#   sudo ./build_image.sh <ngp45ht|pocketais> --fetch-base [--output OUT.img]
#
#   --base BASE.img   use an existing 12 GiB base image
#   --fetch-base      download, verify and unpack the published base image
#   --output OUT.img  output path (default: out/DarkOS4RK3562-<device>.img)
#   --in-place        modify --base directly instead of copying it
#   --outdir DIR      directory for downloaded bases and default output
#
# The source base is never modified unless --in-place is given.  p3 is written
# at 16 MiB and the rootfs overlay is extracted into the BTRFS p4 at 116 MiB.
# Pocket AIS additionally has sectors 64-32767 zeroed and its GPT repaired.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEV=""
BASE=""
OUTPUT=""
OUTDIR="$ROOT/out"
FETCH=0
IN_PLACE=0
OUTPUT_GIVEN=0

usage() {
    sed -n "2,16p" "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage 0 ;;
        --base) BASE=${2:?--base needs an image path}; shift 2 ;;
        --fetch-base) FETCH=1; shift ;;
        --output) OUTPUT=${2:?--output needs a path}; OUTPUT_GIVEN=1; shift 2 ;;
        --outdir) OUTDIR=${2:?--outdir needs a path}; shift 2 ;;
        --in-place) IN_PLACE=1; shift ;;
        -*) echo "unknown option: $1" >&2; usage 1 ;;
        *)
            [ -z "$DEV" ] || { echo "one device per run" >&2; exit 2; }
            DEV=$1; shift
            ;;
    esac
done

case "$DEV" in
    ngp45ht|pocketais) ;;
    *) echo "usage: $0 <ngp45ht|pocketais> (--base IMG | --fetch-base)" >&2; exit 2 ;;
esac

[ "$(id -u)" -eq 0 ] || { echo "building an image needs root (use sudo)" >&2; exit 1; }
[ -n "$BASE" ] || [ "$FETCH" -eq 1 ] || {
    echo "provide --base BASE.img or --fetch-base" >&2
    exit 2
}
[ -z "$BASE" ] || [ "$FETCH" -eq 0 ] || {
    echo "--base and --fetch-base are mutually exclusive" >&2
    exit 2
}
[ "$IN_PLACE" -eq 0 ] || [ "$FETCH" -eq 0 ] || {
    echo "--in-place cannot be combined with --fetch-base (the download is disposable)" >&2
    exit 2
}

for c in mkfs.vfat mcopy python3 sgdisk losetup mount tar sha256sum; do
    command -v "$c" >/dev/null || { echo "missing tool: $c" >&2; exit 1; }
done
if [ "$FETCH" -eq 1 ]; then
    for c in curl xz; do
        command -v "$c" >/dev/null || { echo "missing tool: $c" >&2; exit 1; }
    done
fi

mkdir -p "$OUTDIR"
OUTPUT=${OUTPUT:-"$OUTDIR/DarkOS4RK3562-${DEV}.img"}

if [ "$FETCH" -eq 1 ]; then
    BASE="$OUTDIR/base-${DEV}.img"
    "$ROOT/scripts/fetch_base.sh" "$DEV" "$BASE"
    BUILD="$BASE"
elif [ "$IN_PLACE" -eq 1 ]; then
    if [ "$OUTPUT_GIVEN" -eq 1 ] && [ "$OUTPUT" != "$BASE" ]; then
        echo "--in-place writes to $BASE; do not combine it with --output" >&2
        exit 2
    fi
    OUTPUT="$BASE"
    BUILD="$BASE"
else
    [ -f "$BASE" ] || { echo "base image not found: $BASE" >&2; exit 1; }
    [ "$BASE" != "$OUTPUT" ] || { echo "output must differ from the base image" >&2; exit 1; }
    BUILD="$OUTPUT"
fi

WORK=$(mktemp -d)
MNT="$WORK/p4"
mkdir -p "$MNT"
cleanup() {
    mountpoint -q "$MNT" 2>/dev/null && umount "$MNT" 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

echo "== build $DEV system image =="
"$ROOT/scripts/build_boot.sh" "$DEV" "$WORK/p3.img"
python3 "$ROOT/scripts/build_overlay.py" "$DEV" "$WORK/rootfs.tar"

if [ "$FETCH" -eq 0 ] && [ "$IN_PLACE" -eq 0 ]; then
    echo "copy base: $BASE -> $BUILD"
    cp --sparse=always "$BASE" "$BUILD"
fi

echo "write p3 at 16 MiB"
dd if="$WORK/p3.img" of="$BUILD" bs=1M seek=16 conv=notrunc status=progress

if [ "$DEV" = pocketais ]; then
    echo "zero idbloader/p1/p2 and repair GPT"
    dd if=/dev/zero of="$BUILD" bs=512 seek=64 count=32704 conv=notrunc status=none
    "$ROOT/scripts/fix_gpt.sh" "$BUILD"
fi

echo "extract rootfs overlay into p4"
mount -t btrfs -o loop,rw,offset=121634816 "$BUILD" "$MNT"
tar --numeric-owner -xf "$WORK/rootfs.tar" -C "$MNT"
sync
umount "$MNT"

if [ "$FETCH" -eq 1 ] && [ "$BUILD" != "$OUTPUT" ]; then
    mv -f "$BUILD" "$OUTPUT"
fi

sync
echo "system image: $OUTPUT"
sha256sum "$OUTPUT"
