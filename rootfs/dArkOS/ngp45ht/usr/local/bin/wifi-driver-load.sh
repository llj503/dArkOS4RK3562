#!/bin/sh
# NGP45HT: the wireless module is an AIC8800DC on the USB2 host bus, not the
# SDIO AIC8800D80/RK915 the shared dArkOS rootfs expects.  Try the out-of-tree
# USB stack first and only then fall back to the original SDIO logic.
if modprobe aic8800_fdrv_usb 2>/dev/null; then
    exit 0
fi

if ! modprobe rk915; then
    modprobe aic8800_bsp
    modprobe aic8800_fdrv
fi
