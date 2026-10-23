#!/usr/bin/env bash
# Build the 99 MiB FAT boot partition (p3) for one RK3562 console.
#
# Usage:
#   ./scripts/build_boot.sh <ngp45ht|pocketais> [out.img]
#
# Output: out/DarkOS-<device>-p3.img (or the path given).
# The p3 image contains the common Image/uInitrd, extlinux, the device DTB,
# firstboot/expand scripts, firmware/modules (when present) and battery BMPs.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./scripts/build_boot.sh <ngp45ht|pocketais> [out.img]

Build the 99 MiB p3 FAT boot bundle for one device.
Output: out/DarkOS-<device>-p3.img or the given path.
EOF
    exit 0
}

case "${1:-}" in
    -h|--help) usage ;;
esac

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEV=${1:?usage: build_boot.sh <ngp45ht|pocketais> [out.img]}
OUT=${2:-"$ROOT/out/DarkOS-${DEV}-p3.img"}
COMMON="$ROOT/boot/consoles/kernel/5.10"
DEV_DIR="$ROOT/boot/consoles/$DEV"
P3_BYTES=$((202752 * 512)) # 99 MiB, same as the dArkOS p3 partition

case "$DEV" in
    ngp45ht|pocketais) ;;
    *) echo "unknown device: $DEV" >&2; exit 2 ;;
esac

for f in "$COMMON/Image" "$COMMON/uInitrd" \
         "$DEV_DIR/extlinux/extlinux.conf" "$DEV_DIR/firstboot.sh"; do
    [ -f "$f" ] || { echo "missing: $f" >&2; exit 1; }
done

FDT=$(sed -n 's/^[[:space:]]*FDT[[:space:]]\+\/\([^[:space:]]*\).*/\1/p' \
    "$DEV_DIR/extlinux/extlinux.conf" | head -1)
[ -n "$FDT" ] || { echo "extlinux has no FDT entry" >&2; exit 1; }
[ -f "$DEV_DIR/$FDT" ] || { echo "DTB referenced by extlinux is missing: $DEV_DIR/$FDT" >&2; exit 1; }

echo "== build p3 boot bundle: $DEV =="
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
truncate -s "$P3_BYTES" "$OUT"
mkfs.vfat -F 32 -n dArkOS_Fat "$OUT" >/dev/null

mcopy -i "$OUT" "$COMMON/Image" ::/Image
mcopy -i "$OUT" "$COMMON/uInitrd" ::/uInitrd
mcopy -s -i "$OUT" "$DEV_DIR/extlinux" ::/

for f in "$DEV_DIR"/*.dtb "$DEV_DIR"/*.bmp "$DEV_DIR"/*.sh "$DEV_DIR/fstab.exfat"; do
    [ -e "$f" ] || continue
    mcopy -o -i "$OUT" "$f" "::/$(basename "$f")"
done

for d in firmware modules; do
    [ -d "$DEV_DIR/$d" ] || continue
    mcopy -s -i "$OUT" "$DEV_DIR/$d" ::/
done

# The common firstboot wrapper is also available on p3 for OTA/manual use.
mcopy -o -i "$OUT" "$ROOT/boot/clone.sh" ::/clone.sh

mdir -i "$OUT" ::/extlinux/extlinux.conf >/dev/null
mdir -i "$OUT" ::/Image >/dev/null
mdir -i "$OUT" "::/$FDT" >/dev/null
mdir -i "$OUT" ::/firstboot.sh >/dev/null

echo "== p3 ready: $OUT ($(stat -c %s "$OUT") bytes) =="
sha256sum "$OUT"
