#!/bin/bash
# ============================================================
# sync_image.sh — dArkOS 源树 → 镜像 一键同步
#
# 源树是差异层: boot/ 与 rootfs/ 只放我们构建/修改过的文件 (Image/dtb/脚本/模拟器/库),
# 原厂文件不进源树; rsync 无 --delete, 镜像里的原厂内容不受影响。
# 所有改动只动源树, 然后跑本脚本; 严禁再直接 cp 进镜像 (否则源树与镜像漂移)。
#
# 基准镜像 dArkOS_rg52mini_trixie_06242026.img 永不修改 (对齐 arkos4clone
# build_image.sh 的"源镜像不会被修改"原则): 默认同步到工作副本
# dArkOS3562_work.img, 不存在时自动从基准 cp 创建。
#
# 用法:
#   sudo ./scripts/sync_image.sh                 # 同步到工作副本 (自动创建)
#   sudo ./scripts/sync_image.sh /path/xx.img    # 同步到指定镜像 (基准除外)
#   sudo ./scripts/sync_image.sh --release [img] # 同步后清理首启状态, 另存发布镜像
# ============================================================
set -euo pipefail
D=$(cd "$(dirname "$0")/.." && pwd)
BASE="$D/dArkOS_rg52mini_trixie_06242026.img"
WORK="$D/dArkOS3562_work.img"

RELEASE=no
CI=no
IMG=""
for a in "$@"; do
  case "$a" in
    --release|-r) RELEASE=yes ;;
    --ci|-c) CI=yes ;;
    *) IMG="$a" ;;
  esac
done

if [[ -z "$IMG" ]]; then
  IMG="$WORK"
  if [[ ! -f "$IMG" ]]; then
    [[ -f "$BASE" ]] || { echo "基准镜像不存在: $BASE"; exit 1; }
    echo "== 从基准创建工作副本 (基准不修改): $IMG"
    cp --reflink=auto --sparse=always "$BASE" "$IMG"
  fi
fi
[[ "$IMG" = /* ]] || IMG="$D/$IMG"
[[ -f "$IMG" ]] || { echo "镜像不存在: $IMG"; exit 1; }
if [[ "$(readlink -f "$IMG")" == "$(readlink -f "$BASE")" ]]; then
  echo "✗ 拒绝同步进基准镜像 ($BASE) — 它是只读基准。用工作副本或指定其他镜像。"
  exit 1
fi

# boot 分区必须有关键文件 — 防止半成品源树打包
for f in Image hook.sh firstboot.sh expandtoexfat.sh; do
  [[ -f "$D/boot/$f" ]] || { echo "✗ 源树 boot/ 缺 $f, 中止"; exit 1; }
done

echo "== 源树检查: boot $(find "$D/boot" -type f | wc -l) 文件, rootfs $(find "$D/rootfs" -type f | wc -l) 文件"

echo "== 刷写开源 uboot (原厂 uboot 无法引导我们的内核)"
sudo "$D/uboot/flash_uboot.sh" "$IMG"

sudo "$D/scripts/mount_arkos.sh" mount "$IMG" >/dev/null
trap 'sudo "$D/scripts/mount_arkos.sh" unmount >/dev/null 2>&1' EXIT

echo "== 同步 boot 分区"
# 不加 --delete: 保留 .console 等运行时状态 (工作副本测试启动会留下, 发布时清理)
sudo rsync -a --no-owner --no-group --no-perms --exclude '.console' --exclude '.quirks_applied' --exclude 'extlinux/extlinux.conf' "$D/boot/" "$D/mnt/boot/"
sudo chmod -R 777 "$D/mnt/boot" 2>/dev/null || true

echo "== 同步 rootfs"
# /etc 是系统配置: 属主 root, 权限按源树 (es_systems.cfg 644 等静态件 root:root);
# es_input.cfg 是 ES 运行时可写文件, 原厂归 ark, 排除避免覆盖
if [ -d "$D/rootfs/etc" ]; then
  sudo rsync -a --chown=0:0 --exclude 'emulationstation/es_input.cfg' \
    "$D/rootfs/etc/" "$D/mnt/root/etc/"
fi
# 其余 (usr/local/bin /opt /home/ark 等) 沿用 ArkOS 惯例: ark:1000 + 777
sudo rsync -a --chown=1000:1000 --chmod=D0777,F0777 \
  --exclude '/etc' --exclude '*.so.xz' "$D/rootfs/" "$D/mnt/root/"

# 基准镜像里 klibc-utils 安装时残留的临时文件 (132KB 静态 ELF,
# 不在 dpkg md5sums、也不被 ld.so.cache 引用), 顺手清掉
sudo find "$D/mnt/root/usr/lib" -maxdepth 1 -name 'klibc-*.so' -delete 2>/dev/null || true

# GL/EGL 软链修复: 源树早期误拷入 Debian Mesa 的 libEGL/libGLESv2/libgbm,
# 覆盖了 ArkOS 的 libMali 软链, SDL 会报 "Can't load EGL/GL library"
# 并导致 ES 起不来。这里恢复原厂布局 (全部指向 libMali.so)。
GLDIR="$D/mnt/root/usr/lib/aarch64-linux-gnu"
if [ -d "$GLDIR" ]; then
  sudo rm -f "$GLDIR"/libEGL.so "$GLDIR"/libEGL.so.1 "$GLDIR"/libEGL.so.1.1.0 \
             "$GLDIR"/libEGL_mesa.so.0 "$GLDIR"/libEGL_mesa.so.0.0.0 \
             "$GLDIR"/libGLES_CM.so "$GLDIR"/libGLES_CM.so.1 \
             "$GLDIR"/libGLESv1_CM.so "$GLDIR"/libGLESv1_CM.so.1 "$GLDIR"/libGLESv1_CM.so.1.1.0 \
             "$GLDIR"/libGLESv2.so "$GLDIR"/libGLESv2.so.2 "$GLDIR"/libGLESv2.so.2.0.0 "$GLDIR"/libGLESv2.so.2.1.0 \
             "$GLDIR"/libGLESv3.so "$GLDIR"/libGLESv3.so.3 \
             "$GLDIR"/libgbm.so "$GLDIR"/libgbm.so.1 "$GLDIR"/libgbm.so.1.0.0
  for n in libEGL.so libEGL.so.1 libEGL.so.1.1.0 \
           libGLES_CM.so libGLES_CM.so.1 \
           libGLESv1_CM.so libGLESv1_CM.so.1 libGLESv1_CM.so.1.1.0 \
           libGLESv2.so libGLESv2.so.2 libGLESv2.so.2.0.0 libGLESv2.so.2.1.0 \
           libGLESv3.so libGLESv3.so.3 \
           libgbm.so libgbm.so.1 libgbm.so.1.0.0 \
           libOpenCL.so libMaliOpenCL.so; do
    sudo ln -sfn libMali.so "$GLDIR/$n"
  done
fi

# 已废弃的 RG43V 运行时反转机制 (极性现在由各机型 dtb 的 invert-abs* 决定)
sudo rm -f "$D/mnt/root/etc/udev/rules.d/99-joystick-invert.rules"
sudo rm -f "$D/mnt/root/opt/system/Tools/Left Stick Invert Toggle.sh"

# ZT9101: 相对固件路径已在驱动源码里改为基于 /lib/firmware/zt9101/ 解析,
# cfg 默认值也指向该目录, 不再需要 modprobe 覆盖; 固件按厂商布局放 fw/ 子目录,
# 清掉早期平铺在 zt9101/ 根下的旧副本
sudo rm -f "$D/mnt/root/etc/modprobe.d/zt9101.conf"
sudo rm -f "$D/mnt/root/usr/lib/firmware/zt9101/ZT9101_fw_c1ab8ba.bin" \
           "$D/mnt/root/usr/lib/firmware/zt9101/ZT9101V30_fw_8546b3a.bin"

# DuckStation 只保留官方 mini AppImage; 自编 GPL 版及相关切换文件已废弃
sudo rm -rf "$D/mnt/root/opt/duckstation/duckstationsa" \
            "$D/mnt/root/opt/duckstation/lib" \
            "$D/mnt/root/opt/duckstation/resources" \
            "$D/mnt/root/opt/duckstation/translations"
sudo rm -f "$D/mnt/root/usr/local/bin/standalone-duckstation-gpl" \
           "$D/mnt/root/usr/local/bin/standalone-duckstation-official" \
           "$D/mnt/root/usr/local/bin/duckstation-backend" \
           "$D/mnt/root/home/ark/.config/duckstation.backend"

# Vita3K (PSV) 支持已移除: 清掉早期同步进镜像的启动器 / 程序 / Wayland ICD / 配置
sudo rm -rf "$D/mnt/root/opt/vita3k" "$D/mnt/root/opt/malisx2-wayland" \
            "$D/mnt/root/home/ark/.config/Vita3K"
sudo rm -f "$D/mnt/root/usr/local/bin/vita3k.sh" \
           "$D/mnt/root/usr/local/bin/vita3k-install-firmware.sh"

# LED/风扇持久化改为 ES 启动时执行 darkos-hw-apply.sh, 删除 systemd 单元
sudo rm -f "$D/mnt/root/etc/systemd/system/fanctl.service" \
           "$D/mnt/root/etc/systemd/system/fan-state.service" \
           "$D/mnt/root/etc/systemd/system/led-state.service" \
           "$D/mnt/root/etc/systemd/system/multi-user.target.wants/fanctl.service" \
           "$D/mnt/root/etc/systemd/system/basic.target.wants/fan-state.service" \
           "$D/mnt/root/etc/systemd/system/basic.target.wants/led-state.service"

# wifi-driver-load.service 已被 hook.sh 的 load_wifi_modules 取代:
# 源树不再带 override.conf, 这里直接 mask 掉镜像里的原厂单元, 防止它抢跑
sudo ln -sfn /dev/null "$D/mnt/root/etc/systemd/system/wifi-driver-load.service"

# 模块目录是完整集 (原厂 kernel/ + 我们的 extra/), rsync 后重建依赖索引,
# extra/ 优先级高于 kernel/, 我们重编的 rk915/aic USB 栈覆盖原厂同名模块
echo "== depmod 重建模块依赖"
for vdir in "$D"/rootfs/usr/lib/modules/*/; do
  ver=$(basename "$vdir")
  sudo depmod -b "$D/mnt/root" "$ver"
done

sync
echo "== 校验关键文件"
for f in boot/Image boot/hook.sh root/usr/local/bin/console_detect root/opt/retrorun/retrorun32 root/usr/lib/arm-linux-gnueabihf/libsasl2.so.2; do
  [[ -e "$D/mnt/$f" ]] && echo "✓ $f" || { echo "✗ $f 缺失!"; exit 1; }
done

if [[ "$RELEASE" == "yes" || "$CI" == "yes" ]]; then
  echo "== 发布清理: 恢复首启状态 (.console/.quirks_applied 删除, extlinux 回默认 rg52mini)"
  # 工作副本可能被测试启动过: .console 已写、quirks 标记已落盘、p5 已 exfat、
  # hook 已提升。发布镜像必须让用户设备走完整首启 (hook 全量 quirks + SDL 复制)。
  sudo rm -f "$D/mnt/boot/.console" "$D/mnt/boot/.quirks_applied"
  sudo cp "$D/boot/extlinux/conf.d/rg52mini.conf" "$D/mnt/boot/extlinux/extlinux.conf"
  sync
fi

sudo "$D/scripts/mount_arkos.sh" unmount >/dev/null
trap - EXIT

if [[ "$RELEASE" == "yes" && "$CI" == "no" ]]; then
  base=$(basename "$IMG" .img)
  out="$D/${base}_$(date +%m%d%Y).img"
  echo "== 复制发布镜像: $out"
  cp --reflink=auto --sparse=always "$IMG" "$out"
  sha256sum "$out" > "$out.sha256"
  echo "sha256: $(cut -d' ' -f1 "$out.sha256")"
elif [[ "$CI" == "yes" ]]; then
  echo "== CI 模式: 原地清理, 不做发布副本"
  sha256sum "$IMG" | tee "$IMG.sha256"
fi
echo "== 完成"