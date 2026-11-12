#!/bin/bash
# Clear RK817 POWER_EN_SAVE0/1 so the kernel rk817 reboot notifier does not
# restore POWER_EN on poweroff (that restore makes the device boot again after
# shutdown). Ported from AURKNIX FixShutdown.sh for RK3562.
set -u

log() { echo "$*"; }

compatible="$(tr '\0' ' ' < /proc/device-tree/compatible 2>/dev/null || true)"
case "$compatible" in
  *rockchip,rk3562*|*rockchip,rk3566*) ;;
  *)
    log "rk817-fix-shutdown: not RK3562/RK3566, skip"
    exit 0
    ;;
esac

command -v i2cget >/dev/null 2>&1 && command -v i2cset >/dev/null 2>&1 || {
  log "rk817-fix-shutdown: i2c-tools missing"
  exit 1
}

bus=""
addr=""
for dev in /sys/bus/i2c/devices/*-*; do
  [ -d "$dev" ] || continue
  name="$(cat "$dev/name" 2>/dev/null || true)"
  node_compat=""
  [ -e "$dev/of_node/compatible" ] && \
    node_compat="$(tr '\0' ' ' < "$dev/of_node/compatible" 2>/dev/null || true)"
  case "$name $node_compat" in
    *rk817*|*"rockchip,rk817"*) ;;
    *) continue ;;
  esac
  base="${dev##*/}"
  bus="${base%%-*}"
  addr=$((16#${base#*-}))
  break
done

[ -n "$bus" ] || { log "rk817-fix-shutdown: RK817 not found"; exit 1; }

for reg in 0x99 0xa4; do
  old="$(i2cget -f -y "$bus" "$addr" "$reg" 2>/dev/null || echo ?)"
  i2cset -f -y "$bus" "$addr" "$reg" 0x00 2>/dev/null || true
  new="$(i2cget -f -y "$bus" "$addr" "$reg" 2>/dev/null || echo ?)"
  log "rk817-fix-shutdown: $reg $old -> $new"
done
