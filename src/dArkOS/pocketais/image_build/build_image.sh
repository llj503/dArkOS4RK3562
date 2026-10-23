#!/bin/bash
set -euo pipefail

IMG=/roms/pocketAis-dArkOS-20261019-autoexpand.img
SRC=/dev/mmcblk1
P5_START=24903680
P5_SECTORS=524288
P5_END=$((P5_START + P5_SECTORS - 1))
IMG_SECTORS=$((P5_END + 1 + 34))
IMG_BYTES=$((IMG_SECTORS * 512))

trap 'systemctl start emulationstation >/dev/null 2>&1 || true' EXIT

echo "=== stop EmulationStation ==="
systemctl stop emulationstation || true
sync
sleep 1

echo "=== geometry: p5 ${P5_START}..${P5_END}, image ${IMG_SECTORS} sectors / ${IMG_BYTES} bytes ==="
rm -f "$IMG"

echo "=== copy p1-p4 (12160 MiB, through sector 24903679) ==="
dd if="$SRC" of="$IMG" bs=4M count=3040 conv=fsync status=progress

echo "=== write 256 MiB p5 placeholder ==="
dd if=/dev/zero of="$IMG" bs=4M count=64 seek=3040 conv=fsync status=progress
truncate -s "$IMG_BYTES" "$IMG"

echo "=== new GPT (preserve disk and p1-p4 GUIDs) ==="
/usr/sbin/sgdisk --clear \
  --disk-guid=380FCF94-BE32-4881-B5D0-4364F086DE7F \
  --new=1:16384:24575 --typecode=1:FFFF --change-name=1:uboot --partition-guid=1:4CE8F710-D8AA-4B64-8A23-A61CB6C0652F \
  --new=2:24576:32767 --typecode=2:FFFF --change-name=2:resource --partition-guid=2:7959A2C4-2DE1-4451-9303-FA5D83AEE2F3 \
  --new=3:32768:235519 --typecode=3:0700 --change-name=3:dArkOS_Fat --partition-guid=3:8D14D6BA-FE8D-4971-A653-058337B876FB \
  --new=4:237568:24903679 --typecode=4:0700 --change-name=4:rootfs --partition-guid=4:14A2F32A-21F1-4513-8BB8-1066C69CEA6F \
  --new=5:${P5_START}:${P5_END} --typecode=5:0700 --change-name=5:ROMS --partition-guid=5:0693D428-8F6D-4481-8BB1-7FDA1A3F8FFE \
  "$IMG"

echo "=== clean image p3: remove live marker and firstboot logs ==="
mkdir -p /mnt/pocketais-imgboot
OFF3=$((32768 * 512))
LEN3=$(((235519 - 32768 + 1) * 512))
mount -o loop,rw,offset=$OFF3,sizelimit=$LEN3 "$IMG" /mnt/pocketais-imgboot
rm -f /mnt/pocketais-imgboot/pocketais-autoexpand.done \
      /mnt/pocketais-imgboot/pocketais-diag.txt \
      /mnt/pocketais-imgboot/pocketais-firstboot.log
sync
if [ -e /mnt/pocketais-imgboot/pocketais-autoexpand.done ]; then
  echo "ERROR: marker still present in image p3"
  umount /mnt/pocketais-imgboot
  exit 1
fi
ls -la /mnt/pocketais-imgboot | head -12
umount /mnt/pocketais-imgboot
rmdir /mnt/pocketais-imgboot

echo "=== verify GPT / image ==="
/usr/sbin/sgdisk -p "$IMG"
ls -lh "$IMG"

echo "=== live autoexpand service (skipped by /boot marker) ==="
systemctl is-enabled pocketais-autoexpand.service
systemctl show -p ConditionResult -p ActiveState -p Result pocketais-autoexpand.service
echo "=== done ==="
