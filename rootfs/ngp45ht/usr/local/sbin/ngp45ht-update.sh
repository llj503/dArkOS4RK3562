#!/bin/bash
# NGP45HT post-overlay setup. Idempotent; called by /boot/clone.sh after a
# manually supplied overlay tar is extracted, or manually:
#   sudo /usr/local/sbin/ngp45ht-update.sh
set -u

LOG=/boot/ngp45ht-update.log
exec >>"$LOG" 2>&1
echo "=== ngp45ht-update $(date) ==="

if [ "$(id -u)" -ne 0 ]; then
    echo "must run as root"
    exit 1
fi

SYS=/opt/system

# Stock menu entries replaced by this port's equivalents.  Keep the originals
# as .bak-ngp so nothing is lost if the user wants the dialog version back.
for f in "屏幕色温.sh" "LED Settings.sh" "网络信息.sh" "Wifi.sh"; do
    if [ -e "$SYS/$f" ]; then
        mv -f "$SYS/$f" "$SYS/$f.bak-ngp"
        echo "disabled menu entry: $f"
    fi
done

# Chinese menu names + remove LED Settings / 网络信息 (idempotent).
if [ -x /usr/local/sbin/ngp-rename-menu-zh.sh ]; then
    /usr/local/sbin/ngp-rename-menu-zh.sh | sed 's/^/  /'
fi

# The panel UI runs as ark and writes these two files.
for f in /opt/ngp-panel/panel.conf /opt/ngp-panel/led.conf; do
    [ -f "$f" ] || continue
    chown ark:ark "$f" 2>/dev/null || true
    chmod 0777 "$f" 2>/dev/null || true
done

# Overlay may add modules on an image whose modules.dep predates them.
depmod -a 5.10.226 2>/dev/null || depmod -a 2>/dev/null || true

# The aarch64 GUI binaries are shipped; rebuild only if they are missing.
if [ ! -x /opt/ngp-panel/ngp-panel-gui ] || [ ! -x /opt/ngp-panel/ngp-wifi-gui ]; then
    if command -v gcc >/dev/null 2>&1 && [ -d /usr/include/SDL2 ]; then
        echo "GUI binaries missing, building on device..."
        /opt/ngp-panel/build-gui.sh || echo "WARN: build-gui.sh failed; console UI will be used"
    fi
fi

systemctl daemon-reload

for u in wifi-driver-load ngp-panel-restore ngp-wifi-watchdog zram-swap; do
    systemctl enable "$u" 2>/dev/null || true
done

# ws2812-common is third-party (AURKNIX) and not shipped in this repo.
if [ -x /usr/bin/ws2812-common ]; then
    systemctl enable ngp-stickled 2>/dev/null || true
else
    systemctl disable ngp-stickled 2>/dev/null || true
    echo "ws2812-common absent: stick LED service not enabled"
fi

# Removes the phantom PARTLABEL=swap fstab line (90 s boot stall) and sets up
# zram-swap.  Also idempotent, and safe on an already-fixed card.
if [ -x /usr/local/sbin/ngp-bootspeed-fix.sh ]; then
    /usr/local/sbin/ngp-bootspeed-fix.sh | sed 's/^/  /'
fi

echo "=== ngp45ht-update done ==="
exit 0
