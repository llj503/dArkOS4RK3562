#!/bin/bash
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

IMG=/roms/pocketAis-dArkOS-20261020-autoexpand.img
LOG=/roms/pocketais-image-build-20261020.log
STATUS=/roms/pocketais-image-build-20261020.status
SRC=/dev/mmcblk1

P5_START=$(cat /sys/class/block/mmcblk1p5/start)
P4_START=$(cat /sys/class/block/mmcblk1p4/start)
P5_SECTORS=524288
P5_END=$((P5_START + P5_SECTORS - 1))
IMG_SECTORS=$((P5_END + 1 + 34))
IMG_BYTES=$((IMG_SECTORS * 512))
COPY_SECTORS=$P5_START
COUNT=$((COPY_SECTORS / 8192))
P3_START=32768
P3_END=235519
P4_OFF=$((P4_START * 512))
P4_LEN=$(((P5_START - P4_START) * 512))

exec >>"$LOG" 2>&1
echo "RUNNING" > "$STATUS"
log() { echo "[$(date '+%F %T')] $*"; }

finish() {
    rc=$?
    trap - EXIT
    if [ "$rc" -eq 0 ]; then
        echo "DONE" > "$STATUS"
    else
        echo "FAILED rc=$rc" > "$STATUS"
    fi
    sync
    systemctl start emulationstation >/dev/null 2>&1 || true
    log "exit rc=$rc"
    exit "$rc"
}
trap finish EXIT

log "=== Pocket AIS image build 2026-10-20 ==="
log "p5_start=$P5_START p4_start=$P4_START p5_end=$P5_END image_sectors=$IMG_SECTORS image_bytes=$IMG_BYTES"

[ $((COUNT * 8192)) -eq "$COPY_SECTORS" ] || { log "ERROR: p5 start not 4M aligned"; exit 1; }
avail=$(df -B1 --output=avail /roms | tail -n1 | tr -d ' ')
if [ "$avail" -lt $((IMG_BYTES + 2147483648)) ]; then
    log "ERROR: not enough space on /roms (avail=$avail need>=$((IMG_BYTES + 2147483648)))"
    exit 1
fi
[ -x /usr/sbin/sgdisk ] || { log "ERROR: sgdisk missing"; exit 1; }

log "=== stop EmulationStation ==="
systemctl stop emulationstation || true
sync
sleep 1

log "=== copy p1-p4: ${COPY_SECTORS} sectors (${COUNT} x 4M) ==="
rm -f "$IMG"
dd if="$SRC" of="$IMG" bs=4M count="$COUNT" conv=fsync status=progress
[ "$(stat -c %s "$IMG")" -eq $((COPY_SECTORS * 512)) ] || { log "ERROR: short copy"; exit 1; }

log "=== append 256 MiB p5 placeholder and truncate ==="
dd if=/dev/zero of="$IMG" bs=4M count=64 seek="$COUNT" conv=fsync status=progress
truncate -s "$IMG_BYTES" "$IMG"
[ "$(stat -c %s "$IMG")" -eq "$IMG_BYTES" ] || { log "ERROR: image size mismatch"; exit 1; }

log "=== rebuild GPT ==="
/usr/sbin/sgdisk --clear \
  --disk-guid=380FCF94-BE32-4881-B5D0-4364F086DE7F \
  --new=1:16384:24575 --typecode=1:FFFF --change-name=1:uboot --partition-guid=1:4CE8F710-D8AA-4B64-8A23-A61CB6C0652F \
  --new=2:24576:32767 --typecode=2:FFFF --change-name=2:resource --partition-guid=2:7959A2C4-2DE1-4451-9303-FA5D83AEE2F3 \
  --new=3:${P3_START}:${P3_END} --typecode=3:0700 --change-name=3:dArkOS_Fat --partition-guid=3:8D14D6BA-FE8D-4971-A653-058337B876FB \
  --new=4:${P4_START}:$((P5_START - 1)) --typecode=4:0700 --change-name=4:rootfs --partition-guid=4:14A2F32A-21F1-4513-8BB8-1066C69CEA6F \
  --new=5:${P5_START}:${P5_END} --typecode=5:0700 --change-name=5:ROMS --partition-guid=5:0693D428-8F6D-4481-8BB1-7FDA1A3F8FFE \
  "$IMG"

log "=== clean image p3 boot logs and autoexpand marker ==="
mkdir -p /tmp/pocketais-imgboot
mount -o loop,rw,offset=$((P3_START * 512)),sizelimit=$(((P3_END - P3_START + 1) * 512)) "$IMG" /tmp/pocketais-imgboot
rm -f /tmp/pocketais-imgboot/pocketais-autoexpand.done \
      /tmp/pocketais-imgboot/pocketais-diag.txt \
      /tmp/pocketais-imgboot/pocketais-firstboot.log
sync
if [ -e /tmp/pocketais-imgboot/pocketais-autoexpand.done ]; then
    log "ERROR: autoexpand marker still present"
    exit 1
fi
ls -la /tmp/pocketais-imgboot | head -15
umount /tmp/pocketais-imgboot
rmdir /tmp/pocketais-imgboot

log "=== verify image rootfs (p4, read-only) ==="
mkdir -p /tmp/pocketais-imgroot
LOOP=$(/sbin/losetup -f --show -o "$P4_OFF" --sizelimit "$P4_LEN" "$IMG")
mount -o ro "$LOOP" /tmp/pocketais-imgroot
M=/tmp/pocketais-imgroot

test -x "$M/usr/bin/emulationstation/emulationstation" || { log "ERROR: ES binary missing"; exit 1; }
ES_SIZE=$(stat -c %s "$M/usr/bin/emulationstation/emulationstation")
[ "$ES_SIZE" -gt 5000000 ] || { log "ERROR: ES binary too small ($ES_SIZE)"; exit 1; }

if grep -q '^After=multi-user.target' "$M/etc/systemd/system/pocketais-usb-role.service"; then
    log "ERROR: old USB role ordering in image"
    exit 1
fi
test -L "$M/etc/systemd/system/multi-user.target.wants/pocketais-usb-role-watch.service" || { log "ERROR: USB watcher not enabled"; exit 1; }
test -x "$M/usr/local/sbin/pocketais-usb-role-watch" || { log "ERROR: USB watcher script missing"; exit 1; }

test -x "$M/opt/ngp-panel/ngp-wifi-gui" || { log "ERROR: WiFi GUI missing"; exit 1; }
test -x "$M/opt/ngp-panel/ngp-panel-gui" || { log "ERROR: panel GUI missing"; exit 1; }
test -x "$M/opt/system/网络设置.sh" || { log "ERROR: 网络设置 missing"; exit 1; }
test -x "$M/opt/system/面板调节.sh" || { log "ERROR: 面板调节 missing"; exit 1; }

grep -q 'system_directory = "/roms/bios"' "$M/home/ark/.config/retroarch/retroarch.cfg" || { log "ERROR: RA64 system_directory"; exit 1; }
grep -q 'system_directory = "/roms/bios"' "$M/home/ark/.config/retroarch32/retroarch.cfg" || { log "ERROR: RA32 system_directory"; exit 1; }
grep -q 'input_player1_analog_dpad_mode = "1"' "$M/home/ark/.config/retroarch/retroarch.cfg" || { log "ERROR: RA64 analog dpad"; exit 1; }
grep -q 'input_player1_analog_dpad_mode = "1"' "$M/home/ark/.config/retroarch32/retroarch.cfg" || { log "ERROR: RA32 analog dpad"; exit 1; }
grep -q 'https://buildbot.libretro.com/nightly/linux/aarch64/latest/' "$M/home/ark/.config/retroarch/retroarch.cfg" || { log "ERROR: RA64 core URL"; exit 1; }

log "ES size=$ES_SIZE bytes"
log "USB role unit / watcher / WiFi / panel / RA checks passed"
umount /tmp/pocketais-imgroot
/sbin/losetup -d "$LOOP"
rmdir /tmp/pocketais-imgroot

log "=== verify GPT ==="
/usr/sbin/sgdisk -v "$IMG" || true
/usr/sbin/sgdisk -p "$IMG"
ls -lh "$IMG"
sync
log "=== image build complete ==="
