#!/usr/bin/env bash
# Build the rootfs overlay tar for one RK3562 console.
#
# The tar is meant to be extracted at / on the target rootfs:
#   sudo tar -xf update-darkos-<device>.tar -C /
#
# Usage: scripts/build_update_tar.sh <ngp45ht|pocketais> [out.tar]
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEV=${1:?usage: build_update_tar.sh <ngp45ht|pocketais> [out.tar]}
OUT=${2:-"$ROOT/out/update-darkos-${DEV}.tar"}
COMMON="$ROOT/rootfs/dArkOS/common"
DEV_DIR="$ROOT/rootfs/dArkOS/$DEV"

case "$DEV" in
    ngp45ht|pocketais) ;;
    *) echo "unknown device: $DEV" >&2; exit 2 ;;
esac

[ -d "$COMMON" ] || { echo "missing: $COMMON" >&2; exit 1; }
[ -d "$DEV_DIR" ] || { echo "missing: $DEV_DIR" >&2; exit 1; }

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

# Python rather than tar: on Windows a mounted repo reports 0777 for every
# file, and we want executable bits to depend on content, not the host FS.
# The device overlay is applied after the common overlay, so device files win.
python3 "$ROOT/scripts/make_update_tar.py" "$COMMON" "$DEV_DIR" "$OUT"

tar -tf "$OUT" >/dev/null
sha256sum "$OUT"
