#!/bin/bash
# ============================================================
# write-loader-emmc.sh — 把 Rockchip loader (idblock: DDR 初始化 + SPL)
# 写入 eMMC 的原始区域 (sector 64 起, 第一个分区之前).
#
# 背景: RK3562 掌机 (AIS/RG52 等) 的 BootROM 固定从 eMMC 读 idblock,
# 然后由该 SPL 加载分区里的 U-Boot FIT. 所以更换/升级 loader (例如
# DDR v1.10) 必须写这段原始区域, 普通镜像刷写不一定覆盖它.
#
# 用法:
#   sudo write-loader-emmc.sh <loader.bin> [目标设备, 默认 /dev/mmcblk0]
#
# loader.bin 可以是:
#   - 完整 16MiB 镜像 blob (rk3562-uboot-16m.bin): 取前 8MiB 写入
#   - 8MiB 的 loader 区镜像
#   - 小于 8MiB 的 idblock 镜像 (只覆盖 loader 本体, 其余不动)
#
# 流程: 校验 RKNS 头 -> 备份现有 loader 区 -> dd 写入 -> 回读 sha256 比对
# 备份: /home/ark/loader-backup-<时间>.bin (同尺寸, 可直接写回恢复)
# ============================================================
set -euo pipefail

SRC="${1:-}"
DEV="${2:-/dev/mmcblk0}"
LOADER_START=64                 # sector
LOADER_SECTORS=16320            # 64..16383 = 8MiB - 32KiB, 到第一个分区前
BACKUP_DIR="/home/ark"

die() { echo "✗ $*" >&2; exit 1; }
msg() { echo "== $*"; }

[[ $EUID -eq 0 ]] || die "需要 root: sudo $0 <loader.bin> [设备]"
[[ -n "$SRC" && -f "$SRC" ]] || die "用法: sudo $0 <loader.bin> [设备, 默认 /dev/mmcblk0]"
[[ -b "$DEV" ]] || die "目标不是块设备: $DEV"

DEVNAME="$(basename "$(readlink -f "$DEV")")"
[[ "$DEVNAME" == mmcblk* ]] || die "目标 $DEV 不像 eMMC/SD (期望 mmcblk*)"
[[ "$DEVNAME" != *p* ]] || die "目标应为整盘设备 (如 /dev/mmcblk0), 不是分区"

# RKNS 头 = Rockchip idblock 标志
head4="$(dd if="$SRC" bs=1 count=4 status=none)"
[[ "$head4" == "RKNS" ]] || die "$SRC 不是 Rockchip loader (缺少 RKNS 头)"

SRC_SIZE=$(stat -c %s "$SRC")
MAX_BYTES=$((LOADER_SECTORS * 512))
WRITE_BYTES=$(( SRC_SIZE < MAX_BYTES ? SRC_SIZE : MAX_BYTES ))
WRITE_BYTES=$(( (WRITE_BYTES + 511) / 512 * 512 ))

SYS="/sys/block/$DEVNAME"
if [[ -r "$SYS/size" ]]; then
  msg "目标 $DEV ($DEVNAME), 容量 $(( $(cat "$SYS/size") * 512 / 1024 / 1024 )) MiB"
fi
msg "写入 $SRC (前 $((WRITE_BYTES / 1024)) KiB) -> $DEV sector $LOADER_START"

mkdir -p "$BACKUP_DIR"
# 备份名带机型, 多台机器/多张卡的回滚文件不会混在一起
DEV_MODEL=""
[ -x /usr/local/bin/console_detect ] && DEV_MODEL="$(/usr/local/bin/console_detect -b 2>/dev/null || true)"
[ -n "$DEV_MODEL" ] || DEV_MODEL="$(tr -d '\r\n' < /boot/.console 2>/dev/null || true)"
[ -n "$DEV_MODEL" ] || DEV_MODEL="$(uname -n)"
BACKUP="$BACKUP_DIR/loader-backup-${DEV_MODEL}-$(date +%Y%m%d-%H%M%S).bin"
msg "备份现有 loader 区到 $BACKUP"
dd if="$DEV" of="$BACKUP" bs=512 skip=$LOADER_START count=$LOADER_SECTORS \
  conv=sparse status=none || die "备份失败, 中止"
sync
msg "备份 sha256: $(sha256sum "$BACKUP" | cut -d' ' -f1)"

msg "写入..."
dd if="$SRC" of="$DEV" bs=512 seek=$LOADER_START count=$((WRITE_BYTES / 512)) \
  conv=notrunc,fsync status=none || die "写入失败 (备份在 $BACKUP)"
sync

SRC_SHA=$(dd if="$SRC" bs=512 count=$((WRITE_BYTES / 512)) status=none | sha256sum | cut -d' ' -f1)
DEV_SHA=$(dd if="$DEV" bs=512 skip=$LOADER_START count=$((WRITE_BYTES / 512)) status=none | sha256sum | cut -d' ' -f1)
if [[ "$SRC_SHA" != "$DEV_SHA" ]]; then
  echo "✗ 回读校验失败 (写入 $SRC_SHA, 设备 $DEV_SHA)" >&2
  echo "  恢复: sudo dd if=$BACKUP of=$DEV bs=512 seek=$LOADER_START conv=notrunc,fsync" >&2
  exit 1
fi

msg "✓ 写入并校验成功"
msg "  回读 sha256: $DEV_SHA"
msg "  恢复命令: sudo dd if=$BACKUP of=$DEV bs=512 seek=$LOADER_START conv=notrunc,fsync"
