#!/usr/bin/env bash
# ============================================================
# repart_image.sh — 构建期分区定尺 (对齐 arkos4clone scripts/repart_image.sh)
#
# dArkOS3562 布局 (见 mount_arkos.sh):
#   p1 8M uboot / p2 8M resource / p3 dArkOS_Fat(FAT32, boot)
#   p4 btrfs ROOTFS / p5 ROM (出厂 FAT16 占位)
#
# 目标 (与 arkos4clone 相同):
#   boot (p3) -> 256MiB, rootfs (p4) -> 11264MiB (11G), ROM (p5) -> 尾部剩余
#   出厂镜像的 p5 只是占位; 首启 expandtoexfat.sh 会把它重建成 exFAT 并
#   扩到整卡剩余空间 (rootfs 在设备上不再变动)。
#
# 扩 p3 必须移动 p4/p5 的原始数据 (p4 起始扇区右移), 因此:
#   备份 p3/p5 内容 -> 删除 p5/p4/p3 分区项 -> 镜像尾部加长 shift -> 反向
#   分块 dd 搬运 p4 数据 -> 重建 p3 (mkfs+回填) / p4 (保留 btrfs, resize max)
#   / p5 (原文件系统+卷标, 回填) -> 截回原镜像大小。
#
# 幂等: p3 已 >=256MiB 且 p4 已 >=11G 时只做 btrfs resize, 不碰分区表。
# 用法: sudo ./scripts/repart_image.sh <img>
# ============================================================
set -euo pipefail

IMG="${1:-}"
[[ -n "$IMG" && -f "$IMG" ]] || { echo "用法: $0 <镜像>"; exit 1; }
IMG="$(readlink -f "$IMG")"

BOOT_TARGET_MB=256
ROOT_TARGET_MB=11264          # 11 GiB
SECTOR=512
BOOT_LABEL_DEFAULT="dArkOS_Fat"

WORK_BASE="$(cd "$(dirname "$IMG")" && pwd)"
TMP_DIR="$WORK_BASE/tmp_repart"
MNT_BOOT_OLD="$(mktemp -d -t rp_bootold.XXXXXX)"
MNT_BOOT_NEW="$(mktemp -d -t rp_bootnew.XXXXXX)"
MNT_ROOT="$(mktemp -d -t rp_root.XXXXXX)"
MNT_ROM_OLD="$(mktemp -d -t rp_romold.XXXXXX)"
MNT_ROM_NEW="$(mktemp -d -t rp_romnew.XXXXXX)"
LOOP=""

settle() { command -v udevadm >/dev/null 2>&1 && sudo udevadm settle || sleep 1; }

cleanup() {
  set +e
  for m in "$MNT_BOOT_OLD" "$MNT_BOOT_NEW" "$MNT_ROOT" "$MNT_ROM_OLD" "$MNT_ROM_NEW"; do
    mountpoint -q "$m" && sudo umount "$m"
    rmdir "$m" 2>/dev/null
  done
  [[ -n "${LOOP:-}" ]] && sudo losetup -d "$LOOP" 2>/dev/null
  [[ -d "$TMP_DIR" ]] && sudo rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "== 解除已有 loop"
while read -r dev; do [[ -n "$dev" ]] && sudo losetup -d "$dev" || true; done < <(losetup -j "$IMG" | cut -d: -f1)

loop_map() { LOOP="$(sudo losetup --find --show -P "$IMG")"; settle; }

# ---------- 读取当前布局 ----------
loop_map
P="$(sudo parted -sm "$LOOP" unit s print)"
pstart() { awk -F: -v n="$1" '$1==n{gsub(/s/,"",$2); print $2}' <<< "$P"; }
pend()   { awk -F: -v n="$1" '$1==n{gsub(/s/,"",$3); print $3}' <<< "$P"; }
P3S="$(pstart 3)"; P3E="$(pend 3)"
P4S="$(pstart 4)"; P4E="$(pend 4)"
P5S="$(pstart 5)"; P5E="$(pend 5)"
[[ -n "$P3S" && -n "$P4S" ]] || { echo "✗ 读不到 p3/p4 分区信息"; exit 1; }

IMG_SECTORS=$(( $(stat -c %s "$IMG") / SECTOR ))
P3_MB=$(( (P3E - P3S + 1) * SECTOR / 1024 / 1024 ))
P4_MB=$(( (P4E - P4S + 1) * SECTOR / 1024 / 1024 ))
echo "当前: p3(boot)=${P3_MB}MiB p4(root)=${P4_MB}MiB${P5S:+ p5=$(( (P5E - P5S + 1) * SECTOR / 1024 / 1024 ))MiB}"

need_boot=no; (( P3_MB < BOOT_TARGET_MB )) && need_boot=yes
need_root=no; (( P4_MB < ROOT_TARGET_MB )) && need_root=yes
if [[ "$need_boot" == "no" && "$need_root" == "no" ]]; then
  echo "== 分区已达标"
  # p5 缺失 (例如上次构建中断) 时补一个占位 ROM 分区, 首启会重建为 exFAT
  if [[ -z "${P5S:-}" ]]; then
    NEW_P5_START=$(( P4E + 1 ))
    NEW_P5_END=$(( IMG_SECTORS - 34 ))
    echo "== 补建 p5 占位: ${NEW_P5_START}s-$NEW_P5_END"
    sudo parted -s "$LOOP" unit s mkpart primary "$NEW_P5_START" "${NEW_P5_END}s"
    sudo sfdisk --change-id "$LOOP" 5 6 2>/dev/null || true
    sudo partprobe "$LOOP" || true; settle
    sudo mkfs.vfat -F 16 -n ROMS "${LOOP}p5" >/dev/null
  fi
  echo "== 确保 rootfs 文件系统铺满"
  sudo btrfs device scan --forget 2>/dev/null || true
  sudo mount -t btrfs "${LOOP}p4" "$MNT_ROOT"
  sudo btrfs filesystem resize max "$MNT_ROOT" >/dev/null
  sudo umount "$MNT_ROOT"
  exit 0
fi

# ---------- 备份 p3 / p5 ----------
mkdir -p "$TMP_DIR/bootfs" "$TMP_DIR/romfs"
BOOT_LABEL="$(sudo blkid -s LABEL -o value "${LOOP}p3" 2>/dev/null || true)"
BOOT_LABEL="${BOOT_LABEL:-$BOOT_LABEL_DEFAULT}"
echo "== 备份 p3 (boot, 卷标 $BOOT_LABEL) -> $TMP_DIR/bootfs"
sudo mount -o ro "${LOOP}p3" "$MNT_BOOT_OLD"
sudo rsync -rltD --delete --no-owner --no-group --no-perms --omit-dir-times "$MNT_BOOT_OLD"/ "$TMP_DIR/bootfs"/
sudo umount "$MNT_BOOT_OLD"

ROM_FS=""; ROM_LABEL=""
if [[ -n "${P5S:-}" ]]; then
  ROM_FS="$(sudo blkid -s TYPE -o value "${LOOP}p5" 2>/dev/null || true)"
  ROM_LABEL="$(sudo blkid -s LABEL -o value "${LOOP}p5" 2>/dev/null || true)"
  if [[ -n "$ROM_FS" ]]; then
    echo "== 备份 p5 (rom, $ROM_FS/$ROM_LABEL) -> $TMP_DIR/romfs"
    sudo mount -o ro "${LOOP}p5" "$MNT_ROM_OLD"
    sudo rsync -rltD --no-owner --no-group --no-perms --omit-dir-times "$MNT_ROM_OLD"/ "$TMP_DIR/romfs"/
    sudo umount "$MNT_ROM_OLD"
  fi
fi

# ---------- 删除 p5/p4/p3 分区项 ----------
echo "== 删除 p5/p4/p3 分区项"
for n in 5 4 3; do sudo parted -s "$LOOP" rm "$n" 2>/dev/null || true; done
sudo partprobe "$LOOP" || true

# ---------- 计算新布局 ----------
NEW_P3_START=$P3S
NEW_P3_END=$(( NEW_P3_START + BOOT_TARGET_MB * 1024 * 1024 / SECTOR - 1 ))
NEW_P4_START=$(( NEW_P3_END + 1 ))
# p4 起点 1MiB 对齐
ALIGN=$(( 1024 * 1024 / SECTOR ))
NEW_P4_START=$(( ((NEW_P4_START + ALIGN - 1) / ALIGN) * ALIGN ))
NEW_P4_END=$(( NEW_P4_START + ROOT_TARGET_MB * 1024 * 1024 / SECTOR - 1 ))
NEW_P5_START=$(( NEW_P4_END + 1 ))
NEW_P5_END=$(( IMG_SECTORS - 34 ))   # GPT 备份表占尾部 33 扇区
SHIFT=$(( NEW_P4_START - P4S ))
echo "目标: p3=${BOOT_TARGET_MB}MiB(${NEW_P3_START}s-${NEW_P3_END}s) p4=${ROOT_TARGET_MB}MiB(${NEW_P4_START}s-${NEW_P4_END}s) p5=$(( (NEW_P5_END - NEW_P5_START + 1) * SECTOR / 1024 / 1024 ))MiB"
echo "p4 数据右移 ${SHIFT} 扇区 ($(( SHIFT * SECTOR / 1024 / 1024 ))MiB)"

(( SHIFT > 0 )) || { echo "✗ 非预期: shift<=0"; exit 1; }

# ---------- 加长镜像 -> 反向搬运 p4 数据 ----------
MOVE_SRC=$(( P4S * SECTOR ))
MOVE_LEN=$(( (P4E - P4S + 1) * SECTOR ))
echo "== 镜像临时加长 $(( SHIFT * SECTOR / 1024 / 1024 ))MiB"
truncate -s +"$(( SHIFT * SECTOR ))" "$IMG"
sudo losetup -d "$LOOP"; LOOP=""
CHUNK=$(( 64 * 1024 * 1024 ))
remaining=$MOVE_LEN
src_off=$(( MOVE_SRC + MOVE_LEN ))
echo "== 搬运 p4 数据 $(( MOVE_LEN / 1024 / 1024 ))MiB (反向分块)"
while (( remaining > 0 )); do
  (( n = remaining < CHUNK ? remaining : CHUNK ))
  src_off=$(( src_off - n ))
  sudo dd if="$IMG" of="$IMG" bs="$CHUNK" conv=notrunc status=none \
    iflag=count_bytes,skip_bytes oflag=seek_bytes \
    skip="$src_off" seek="$(( src_off + SHIFT * SECTOR ))" count="$n"
  remaining=$(( remaining - n ))
done
sync

# 截回原大小 (p5 结束扇区 = 原镜像末尾)
truncate -s $(( IMG_SECTORS * SECTOR )) "$IMG"
loop_map
echo "loop: $LOOP"

# ---------- 重建 p3 ----------
echo "== 重建 p3: ${BOOT_TARGET_MB}MiB FAT32"
sudo parted -s "$LOOP" unit s mkpart primary fat32 "${NEW_P3_START}s" "${NEW_P3_END}s"
sudo sfdisk --change-id "$LOOP" 3 b 2>/dev/null || true
sudo partprobe "$LOOP" || true; settle
sudo mkfs.vfat -F 32 -n "$BOOT_LABEL" "${LOOP}p3" >/dev/null
sudo mount "${LOOP}p3" "$MNT_BOOT_NEW"
sudo rsync -rltD --no-owner --no-group --no-perms --omit-dir-times "$TMP_DIR/bootfs"/ "$MNT_BOOT_NEW"/
sync
sudo umount "$MNT_BOOT_NEW"

# ---------- 重建 p4 并铺满文件系统 ----------
echo "== 重建 p4: ${ROOT_TARGET_MB}MiB (btrfs, 数据已搬运)"
sudo parted -s "$LOOP" unit s mkpart primary "${NEW_P4_START}s" "${NEW_P4_END}s"
sudo partprobe "$LOOP" || true; settle
sudo btrfs device scan --forget 2>/dev/null || true
sudo mount -t btrfs "${LOOP}p4" "$MNT_ROOT"
sudo btrfs filesystem resize max "$MNT_ROOT" >/dev/null
sudo umount "$MNT_ROOT"

# ---------- 重建 p5 ----------
if [[ -n "${ROM_FS:-}" ]]; then
  echo "== 重建 p5: $ROM_FS/$ROM_LABEL (${NEW_P5_START}s-${NEW_P5_END}s)"
  sudo parted -s "$LOOP" unit s mkpart primary "${NEW_P5_START}s" "${NEW_P5_END}s"
  sudo sfdisk --change-id "$LOOP" 5 6 2>/dev/null || true
  sudo partprobe "$LOOP" || true; settle
  case "$ROM_FS" in
    vfat|fat32|fat16) sudo mkfs.vfat -F 16 -n "$ROM_LABEL" "${LOOP}p5" >/dev/null 2>&1 || sudo mkfs.vfat -n "$ROM_LABEL" "${LOOP}p5" >/dev/null ;;
    exfat)            sudo mkfs.exfat -n "$ROM_LABEL" "${LOOP}p5" >/dev/null ;;
    *)                sudo mkfs.exfat -n "${ROM_LABEL:-ROMS}" "${LOOP}p5" >/dev/null ;;
  esac
  sudo mount "${LOOP}p5" "$MNT_ROM_NEW"
  sudo rsync -rltD --no-perms --no-owner --no-group "$TMP_DIR/romfs"/ "$MNT_ROM_NEW"/
  sync
  sudo umount "$MNT_ROM_NEW"
fi

# 截回原大小后, GPT 备份表还在"加长后"的尾部位置 → 用 sgdisk 把它挪回盘尾,
# 否则 parted/sgdisk 每次都会报 "backup GPT table is corrupt".
if command -v sgdisk >/dev/null 2>&1; then
  sudo sgdisk -e "$LOOP" >/dev/null 2>&1 || true
  sudo partprobe "$LOOP" || true; settle
fi

echo "== 最终布局"
sudo parted "$LOOP" unit MiB print
echo "✅ repart 完成"
