#!/bin/bash
# RK3562/RK817 poweroff.
#
# 1. Clear POWER_EN_SAVE0/1 (0x99/0xa4). The kernel rk817 reboot notifier
#    restores POWER_EN from these on poweroff, which makes the PMIC power the
#    rails back up -> device boots again after shutdown.
# 2. Write DEV_OFF (SYS_CFG3 0xf4 bit0) to cut power directly; this bypasses
#    ATF's broken SYSTEM_OFF (SLPPIN with pmic-reset-func=0 resets instead).
/usr/local/bin/rk817-fix-shutdown.sh 2>/dev/null || true
i2cset -f -y 0 0x20 0xf4 0x01
sync
