#!/bin/sh
# wifi-load.sh -- load the WiFi stack described by the device tree.
#
# SDIO boards cannot autoload by modalias: the chip is powered off until the
# driver raises WIFI,poweren_gpio in probe, so there is no sdio: modalias for
# udev to match. The stack is therefore chosen from the board's DTB:
#   wifi_chip_type = "aic8800D80" -> aic8800_bsp, then aic8800_fdrv
#   wifi_chip_type = "rk915"      -> rk915
# USB boards (wireless-wlan disabled or absent) need the firmware loader
# before the driver.
#
# Run in the background at boot (systemd-run --unit=wifi-load), idempotent.

DT=/proc/device-tree/wireless-wlan
CHIP=""
STATUS="okay"

[ -r "$DT/wifi_chip_type" ] && CHIP=$(tr -d '\0' < "$DT/wifi_chip_type")
[ -r "$DT/status" ] && STATUS=$(tr -d '\0' < "$DT/status")

loaded() { [ -d "/sys/module/$1" ]; }

load_retry() {
	drv="$1"
	loaded "$drv" && return 0
	i=0
	while [ "$i" -lt 3 ]; do
		if modprobe "$drv" 2>/dev/null; then
			logger -t wifi-load "loaded $drv" 2>/dev/null
			return 0
		fi
		i=$((i + 1))
		sleep 1
	done
	logger -t wifi-load "failed to load $drv" 2>/dev/null
	return 1
}

if [ "$STATUS" != "okay" ]; then
	# USB boards: two-stage AIC stack, firmware loader first.
	load_retry aic_load_fw_usb || exit 1
	sleep 1
	load_retry aic8800_fdrv_usb || exit 1
	logger -t wifi-load "USB stack ready" 2>/dev/null
	exit 0
fi

case "$CHIP" in
	rk915)
		load_retry rk915 || exit 1
		;;
	*)
		# SDIO AIC8800D80 (and anything not described otherwise).
		load_retry aic8800_bsp || exit 1
		sleep 1
		load_retry aic8800_fdrv || exit 1
		;;
esac

logger -t wifi-load "SDIO stack ready ($CHIP)" 2>/dev/null
exit 0
