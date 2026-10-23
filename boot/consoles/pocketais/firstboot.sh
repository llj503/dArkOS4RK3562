#!/bin/bash
# Pocket AIS (RK3562 / AIC8800D80 SDIO) first-boot setup for dArkOS.
# Runs from the FAT /boot partition after the rootfs is mounted.
set -u

LOG=/boot/pocketais-firstboot.log
exec >>"$LOG" 2>&1
echo "=== $(date) Pocket AIS firstboot ==="
echo "kernel: $(uname -r)"
tr -d '\0' < /proc/device-tree/model 2>/dev/null; echo

# --- SSH access -------------------------------------------------------------
if [ -f /boot/authorized_keys ]; then
  for home in /home/ark /root; do
    [ -d "$home" ] || continue
    mkdir -p "$home/.ssh"
    chmod 700 "$home/.ssh"
    cat /boot/authorized_keys >> "$home/.ssh/authorized_keys"
    sort -u "$home/.ssh/authorized_keys" -o "$home/.ssh/authorized_keys"
    chmod 600 "$home/.ssh/authorized_keys"
    chown -R "$(stat -c %u:%g "$home")" "$home/.ssh"
    echo "installed ssh key in $home"
  done
fi
systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null

# --- AIC8800D80 SDIO firmware and driver -----------------------------------
if [ -d /boot/firmware ]; then
  mkdir -p /lib/firmware/aic8800 /usr/lib/firmware/aic8800 2>/dev/null
  cp -f /boot/firmware/* /lib/firmware/ 2>/dev/null
  cp -f /boot/firmware/* /usr/lib/firmware/ 2>/dev/null
  cp -f /boot/firmware/* /lib/firmware/aic8800/ 2>/dev/null
  cp -f /boot/firmware/* /usr/lib/firmware/aic8800/ 2>/dev/null
  echo "installed AIC firmware"
fi

KREL=$(uname -r)
MODDIR="/lib/modules/$KREL/extra/pocketais"
if [ -d /boot/modules ]; then
  mkdir -p "$MODDIR"
  cp -f /boot/modules/*.ko "$MODDIR/" 2>/dev/null
  depmod -a "$KREL" 2>/dev/null || depmod -a 2>/dev/null || true
  echo "installed AIC modules to $MODDIR"
fi

# Prefer the SDIO modules from /boot; unload any USB AIC variant loaded by the
# base image.  (Pocket AIS has AIC8800D80 on SDIO, not the NGP45HT USB part.)
for m in aic8800_fdrv aic8800_bsp aic8800_fdrv_usb aic_load_fw_usb; do
  rmmod "$m" 2>/dev/null || true
done
insmod "$MODDIR/aic8800_bsp.ko" 2>/dev/null || modprobe aic8800_bsp 2>/dev/null
insmod "$MODDIR/aic8800_fdrv.ko" 2>/dev/null || modprobe aic8800_fdrv 2>/dev/null
systemctl restart NetworkManager 2>/dev/null || true

# --- one-shot report readable from the FAT partition -----------------------
{
  echo "===== Pocket AIS diag $(date) ====="
  uname -a
  tr -d '\0' < /proc/device-tree/model; echo
  echo "--- lsmod"; lsmod
  echo "--- sdio"
  ls -l /sys/bus/sdio/devices 2>/dev/null
  for d in /sys/bus/sdio/devices/*; do
    [ -e "$d" ] || continue
    echo "$d vendor=$(cat "$d/vendor" 2>/dev/null) device=$(cat "$d/device" 2>/dev/null)"
    readlink -f "$d/driver" 2>/dev/null
  done
  echo "--- dmesg"
  dmesg 2>/dev/null | grep -iE 'aic|sdio|mmc|joystick|panel|rk817|firmware|wlan' | tail -200
  echo "--- net"
  ip -br link 2>/dev/null
  iw dev 2>/dev/null
  command -v nmcli >/dev/null 2>&1 && { nmcli device status; nmcli device wifi list; }
  echo "--- input"
  grep -E '^(N:|P:|H:)' /proc/bus/input/devices 2>/dev/null
} > /boot/pocketais-diag.txt 2>&1

exit 0
