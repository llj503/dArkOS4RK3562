#!/bin/bash
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
gcc $CFLAGS -o vita3k-osd vita3k-osd-wl.c xdg-shell-protocol.c \
    $(pkg-config --cflags --libs wayland-client freetype2) $LIBS
gcc $CFLAGS -o vita3k-frontend vita3k-frontend-wl.c xdg-shell-protocol.c \
    $(pkg-config --cflags --libs wayland-client freetype2 libpng) $LIBS
install -m 755 vita3k-osd /usr/local/bin/vita3k-osd
install -m 755 vita3k-frontend /usr/local/bin/vita3k-frontend
echo "built; data root = $DATA"
