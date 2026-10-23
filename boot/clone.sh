#!/bin/sh
# dArkOS4RK3562 common firstboot wrapper.
#
# This is intentionally small: the device-specific work is in each console's
# firstboot.sh (firmware/modules/SSH/audio/controls/expansion).  The wrapper:
#   1. detects the console from the DTB model (or /boot/darkos4rk3562.device);
#   2. applies /update-darkos-<device>.tar if present;
#   3. runs /firstboot.sh (the device firstboot from the boot bundle).
set -u

LOG=/boot/darkos4rk3562-firstboot.log
exec >>"$LOG" 2>&1
echo "=== dArkOS4RK3562 firstboot $(date) ==="

if [ -f /boot/darkos4rk3562.device ]; then
    DEV=$(cat /boot/darkos4rk3562.device)
else
    MODEL=$(tr -d '\0' </proc/device-tree/model 2>/dev/null || true)
    case "$MODEL" in
        *NGP45HT*) DEV=ngp45ht ;;
        *"Pocket AIS"*|*RK3562*EVB*|*ro520c*) DEV=pocketais ;;
        *) DEV=pocketais ;;
    esac
fi
echo "device=$DEV model=$(tr -d '\0' </proc/device-tree/model 2>/dev/null || true)"

case "$DEV" in
    ngp45ht|pocketais) ;;
    *) echo "unknown device $DEV, aborting"; exit 1 ;;
esac

OVERLAY="/update-darkos-$DEV.tar"
if [ -f "$OVERLAY" ]; then
    echo "applying $OVERLAY"
    tar --numeric-owner -xf "$OVERLAY" -C / || echo "WARN: overlay extraction failed"
else
    echo "no rootfs overlay tar on boot partition"
fi

# Device post-overlay steps must run before /firstboot.sh: the latter ends by
# expanding /roms and rebooting.
if [ "$DEV" = ngp45ht ] && [ -x /usr/local/sbin/ngp45ht-update.sh ]; then
    echo "running /usr/local/sbin/ngp45ht-update.sh"
    /usr/local/sbin/ngp45ht-update.sh || echo "WARN: ngp45ht-update.sh failed"
fi

if [ -x /firstboot.sh ]; then
    echo "running device firstboot /firstboot.sh"
    /firstboot.sh
else
    echo "WARN: /firstboot.sh missing"
fi

exit 0
