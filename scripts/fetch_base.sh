#!/usr/bin/env bash
# Download, verify and unpack the published base image for one console.
#
# Usage:
#   ./scripts/fetch_base.sh <ngp45ht|pocketais> <out.img>
#
# The base images are external (12-13 GiB raw) and are published as split xz
# parts.  This helper downloads the parts and the release checksum file,
# verifies the parts, streams them through xz into <out.img>, and deletes the
# parts.  It never writes outside the output directory and needs ~17 GiB free.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./scripts/fetch_base.sh <ngp45ht|pocketais> <out.img>

Download the published split-xz base image, verify its release checksums,
unpack it to <out.img> and delete the downloaded parts.
EOF
    exit 0
}

case "${1:-}" in
    -h|--help) usage ;;
esac

DEV=${1:?usage: fetch_base.sh <ngp45ht|pocketais> <out.img>}
OUT=${2:?usage: fetch_base.sh <ngp45ht|pocketais> <out.img>}

case "$DEV" in
    ngp45ht)
        RELEASE="https://github.com/llj503/dArkOS_ngp45ht/releases/download/ngp45ht-20261020"
        SUMS="sha256sums.txt"
        PARTS=(
            dArkOS_ngp45ht_trixie_20261020.img-00.img.xz.part
            dArkOS_ngp45ht_trixie_20261020.img-01.img.xz.part
            dArkOS_ngp45ht_trixie_20261020.img-02.img.xz.part
        )
        ;;
    pocketais)
        RELEASE="https://github.com/llj503/dArkOS-PokectAis/releases/download/dArkOS-20261020"
        SUMS="SHA256SUMS.txt"
        PARTS=(
            pocketAis-dArkOS-20261020-autoexpand-sanitized.img.xz.part-00
            pocketAis-dArkOS-20261020-autoexpand-sanitized.img.xz.part-01
        )
        ;;
    *)
        echo "unknown device: $DEV" >&2
        exit 2
        ;;
esac

mkdir -p "$(dirname "$OUT")"
OUT=$(readlink -f "$OUT")
WORK="$(dirname "$OUT")/.fetch-base-$DEV"
rm -rf "$WORK"
mkdir -p "$WORK"
trap 'rc=$?; [ "$rc" -eq 0 ] || rm -f "$OUT"; rm -rf "$WORK"' EXIT
cd "$WORK"

AVAIL=$(df -Pk "$(dirname "$OUT")" | awk 'NR==2 {print $4}')
if [ "${AVAIL:-0}" -lt $((17 * 1024 * 1024)) ]; then
    echo "need at least 17 GiB free next to $OUT (have ${AVAIL:-0} KiB)" >&2
    exit 1
fi

echo "== fetch $DEV base =="
curl -fL --retry 3 --retry-delay 2 -o "$SUMS" "$RELEASE/$SUMS"
# Keep only the part lines: the AIS file also lists the full raw/xz files.
grep -E '\.part(-[0-9]+)?$' "$SUMS" > parts.sha256
[ -s parts.sha256 ] || { echo "no part checksums in $SUMS" >&2; exit 1; }

for p in "${PARTS[@]}"; do
    echo "download $p"
    curl -fL --retry 3 --retry-delay 2 -o "$p" "$RELEASE/$p"
done

echo "verify parts"
sha256sum -c parts.sha256

echo "unpack -> $OUT"
cat "${PARTS[@]}" | xz -dc > "$OUT"

SIZE=$(stat -c %s "$OUT")
if [ "$SIZE" -lt $((11 * 1024 * 1024 * 1024)) ]; then
    echo "unpacked image is too small: $SIZE bytes" >&2
    rm -f "$OUT"
    exit 1
fi
echo "== base ready: $OUT ($SIZE bytes) =="
