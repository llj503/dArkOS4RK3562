#!/bin/sh
# wifi-load.sh -- load the WiFi stack described by the device tree.
#
# SDIO boards cannot autoload by modalias: the chip is powered off until the
# driver raises WIFI,poweren_gpio in probe, so there is no sdio: modalias for
# udev to match. The stack is therefore chosen from the board's DTB:
#   SDIO boards: try rk915 first (its probe verifies the silicon and backs
#   off cleanly on mismatch), then the AIC8800 stack. The DTB chip type is
#   advisory - several boards ship either RK915 or AIC8800D80 under the same
#   string, so do not trust it to pick the driver.
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

# The SDIO host must exist before probing; the async unit can start earlier
# than the old synchronous hook did.
i=0
while [ "$i" -lt 20 ] && ! ls /sys/class/mmc_host/mmc* >/dev/null 2>&1; do
	sleep 0.5
	i=$((i + 1))
done

# Cache the detected stack per physical unit. Device model and CPU model are
# identical across boards that ship either RK915 or AIC8800D80, so key on the
# SoC serial number (unique per unit) and fall back to machine-id.
UNIT=$(tr -d '\0' < /proc/device-tree/serial-number 2>/dev/null | tr -c 'A-Za-z0-9' '_')
[ -n "$UNIT" ] || UNIT=$(tr -d '-' < /etc/machine-id 2>/dev/null)
[ -n "$UNIT" ] || UNIT=unknown
CACHE="/home/ark/.config/wifi-load.$UNIT.driver"

wlan_up() {
	i=0
	while [ "$i" -lt 10 ]; do
		ls /sys/class/net/wlan* >/dev/null 2>&1 && return 0
		sleep 0.5
		i=$((i + 1))
	done
	return 1
}

load_rk915() {
	modprobe rk915 2>/dev/null || return 1
	logger -t wifi-load "loaded rk915" 2>/dev/null
	wlan_up
}

load_aic() {
	load_retry aic8800_bsp || return 1
	sleep 1
	load_retry aic8800_fdrv || return 1
	wlan_up
}

remember() {
	mkdir -p "$(dirname "$CACHE")"
	printf '%s\n' "$1" > "$CACHE"
	chown ark:ark "$CACHE" 2>/dev/null
	logger -t wifi-load "SDIO stack ready ($1)" 2>/dev/null
}

# Already loaded (e.g. the script was rerun manually): just remember it.
if loaded rk915; then
	remember rk915
	exit 0
fi
if loaded aic8800_fdrv; then
	remember aic8800
	exit 0
fi

if [ -r "$CACHE" ]; then
	case "$(cat "$CACHE" 2>/dev/null)" in
	rk915)
		load_rk915 && exit 0
		;;
	aic8800)
		load_aic && exit 0
		;;
	esac
fi

# rk915 probe checks the silicon and backs off on AIC hardware, and loading
# the AIC stack first on an RK915 board leaves the shared power rail claimed,
# so keep rk915 first and make it a single probe.
if load_rk915; then remember rk915; exit 0; fi
if load_aic; then remember aic8800; exit 0; fi

logger -t wifi-load "no SDIO WiFi stack came up (dtb said $CHIP)" 2>/dev/null
exit 1
