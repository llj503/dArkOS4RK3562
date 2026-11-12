#!/bin/bash
# ============================================================
# flash_uboot.sh — 把 AveyondFly rk3562 分支构建的开源 uboot 写进镜像
#
# 产物来自 ~/AveyondFly-u-boot (rk3562 分支) build_uboot_rk3562.sh:
#   rk3562-uboot-16m.bin — sector 64 起的分区前合并镜像:
#     +0KiB / +512KiB : idblock 双份冗余 (DDR init + SPL)
#     blob sector 16320 → 磁盘 sector 16384 (8MiB, p1): uboot FIT 4MiB
#     结尾恰好到 16MiB (p3 boot 分区起点), 不会越界
#   含关机充电修复 + 显示支持 (CONFIG_DM_CHARGE_DISPLAY/DM_VIDEO)
# 原厂 uboot 无法引导我们的内核/设备树, 工作/发布镜像必须刷开源版。
# 基准镜像禁止写入 (由 sync_image.sh 拦截, 这里也独立检查)。
#
# 用法: sudo ./uboot/flash_uboot.sh <image.img>
# ============================================================
set -euo pipefail
D=$(cd "$(dirname "$0")/.." && pwd)
IMG="${1:?用法: sudo $0 <image.img>}"
[[ "$IMG" = /* ]] || IMG="$D/$IMG"
[[ -f "$IMG" ]] || { echo "镜像不存在: $IMG"; exit 1; }

BASE="$D/dArkOS_rg52mini_trixie_06242026.img"
if [[ -f "$BASE" && "$(readlink -f "$IMG")" == "$(readlink -f "$BASE")" ]]; then
  echo "✗ 拒绝刷写基准镜像 — 它是只读基准"
  exit 1
fi

BLOB="$D/uboot/rk3562-uboot-16m.bin"
[[ -f "$BLOB" ]] || { echo "✗ 缺少产物: $BLOB (先在 ~/AveyondFly-u-boot 跑 build_uboot_rk3562.sh 并复制过来)"; exit 1; }
# 16MiB - 64 扇区: 从 sector 64 写到 16MiB 边界
[[ $(stat -c%s "$BLOB") -eq $((16 * 1024 * 1024 - 64 * 512)) ]] || { echo "✗ rk3562-uboot-16m.bin 尺寸不对"; exit 1; }

dd if="$BLOB" of="$IMG" bs=512 seek=64 conv=notrunc,fsync status=none
echo "✓ AveyondFly rk3562 uboot 已写入: sector 64 起 (idblock 双份 + FIT@16384)"