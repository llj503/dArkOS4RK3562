#!/bin/bash
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
for f in BUILD-INFO.txt VkLayer_window_system_integration.json          libVkLayer_window_system_integration.so; do
    copy "$S/wsi/$f" "$D/rootfs/opt/vita3k-wsi/$f" bin 644
done
for f in theme.xml system.png background_icon.png; do
    copy "$S/theme/$f" "$D/rootfs/tempthemes/es-theme-nes-box/psvita/$f" bin 644
done
# ES entry must point at /usr/local/bin/psv.sh
CFG="$D/rootfs/etc/emulationstation/es_systems.cfg"
if [ -f "$CFG" ] && grep -q '<name>psvita</name>' "$CFG"; then
    # Only fix the psvita command; never touch other systems' <command>.
    sed -i 's|<command>/usr/local/bin/psvita-launch.sh %ROM%</command>|<command>/usr/local/bin/psv.sh %ROM%</command>|' "$CFG"
else
    python3 "$S/patch_es_vita.py" "$CFG"
    sed -i 's|/usr/local/bin/psvita-launch.sh|/usr/local/bin/psv.sh|' "$CFG"
fi
# /opt/vita3k/portable is created at first boot by the launcher; keep the
# binary bundle itself untouched (release asset, already in rootfs/opt/vita3k).
echo "== Vita3K: done. Run scripts/sync_image.sh to write the image. =="
