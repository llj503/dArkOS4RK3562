#!/usr/bin/env bash
# Repair the Pocket AIS TF GPT so the eMMC U-Boot accepts the card.
#
# Sets:
#   p1 type = a60b0000-0000-4c7e-8000-015e00004db7 (Rockchip uboot)
#   p2 type = d46e0000-0000-457f-8000-220d000030db (Rockchip resource)
#   p3 attr = 0x4 (legacy BIOS bootable)
#
# sgdisk rewrites the primary and backup GPTs and their CRC32s, and leaves the
# disk/partition unique GUIDs and start/end sectors alone.
#
# Usage: scripts/fix_gpt.sh <image.img>
set -euo pipefail

IMG=${1:?usage: fix_gpt.sh <image.img>}
[ -f "$IMG" ] || { echo "image not found: $IMG" >&2; exit 1; }
command -v sgdisk >/dev/null || { echo "sgdisk not found (install gdisk)" >&2; exit 1; }

HDR=$(dd if="$IMG" bs=1 skip=512 count=8 status=none)
[ "$HDR" = "EFI PART" ] || { echo "no GPT header at LBA 1: $IMG" >&2; exit 1; }

P1=a60b0000-0000-4c7e-8000-015e00004db7
P2=d46e0000-0000-457f-8000-220d000030db

sgdisk \
    -t "1:$P1" \
    -t "2:$P2" \
    -A 3:set:2 \
    "$IMG"

echo "verify"
sgdisk -i 1 "$IMG" | grep -qi "$P1" || { echo "p1 type verify failed" >&2; exit 1; }
sgdisk -i 2 "$IMG" | grep -qi "$P2" || { echo "p2 type verify failed" >&2; exit 1; }
ATTR=$(sgdisk -i 3 "$IMG" | sed -n 's/^Attribute flags: *//p')
[ "$ATTR" = "0000000000000004" ] || {
    echo "p3 attribute verify failed: ${ATTR:-<missing>}" >&2
    exit 1
}
sgdisk -v "$IMG" | grep -qi 'No problems found' || {
    echo "sgdisk -v reported GPT problems" >&2
    exit 1
}
echo "GPT repaired: p1=RK uboot, p2=RK resource, p3 bootable"
