# dArkOS RG52Mini (trixie) 镜像定制

参考 [~/arkos4clone](https://github.com/lcdyk0517/arkos4clone) 的结构逻辑，
针对 `dArkOS_rg52mini_trixie_06242026.img`（RK3562 / Debian trixie / GPT）。

## 镜像分区布局（trixie, 与 H700 三分区布局不同）

| 分区 | 偏移 | 大小 | 文件系统 | 卷标 | 挂载为 | 说明 |
|---|---|---|---|---|---|---|
| p1 | 8M | 4M | DTB blob | — | — | uboot FIT 区，sync 刷入开源 uboot |
| p2 | 12M | 4M | data | — | — | uboot 相关（全零），**不动** |
| p3 | 16M | 99M | FAT32 | `dArkOS_Fat` | `/boot` | 内核 Image/uInitrd/extlinux/dtb/电池图 |
| p4 | 116M | 11.8G | btrfs (zstd) | `ROOTFS` | `/` | rootfs，用户 `ark` uid=1000 |
| p5 | 12.1G | 79M | FAT16 | `ROMS` | `/roms` | 占位分区，首启 `expandtoexfat.sh` 转 exFAT 并解包 `/roms.tar` |

引导链：uboot → extlinux (`p3:/extlinux/extlinux.conf`) → `Image` + `rk3562-rg52mini.dtb` + `uInitrd` → `root=/dev/mmcblk1p4 btrfs`。
首启：`firstboot.sh` → `expandtoexfat.sh`（p5 转 exFAT 卷标 EASYROMS、解包 `/roms.tar`、`tempthemes` → `/roms/themes/`、切换 `fstab.exfat`），`/roms/tools` bind 到 `/opt/system/Tools`。

## 目录结构（对齐 arkos4clone）

```
dArkOS/
├── scripts/
│   └── mount_arkos.sh   # 镜像挂载/卸载（分区按 TYPE+LABEL 自动识别，兼容 trixie 与 H700 布局）
├── boot/                # -> rsync 进镜像 p3（对应 arkos4clone 的 boot/dArkOS）
├── rootfs/              # -> rsync 进镜像 p4（对应 arkos4clone 的 rootfs/dArkOS，属主 1000:1000）
├── roms/                # -> 打包为镜像内 /roms.tar（增量 + 原厂骨架合并）
├── uboot/               # 开源 uboot 产物 (来自 ~/AveyondFly-u-boot rk3562 分支) + flash_uboot.sh
└── .probe/              # 免 root 解包产物（可直接浏览，可删）
    ├── rootfs_x/        # p4 btrfs 完整还原（8.7G 解压后）
    └── rootfs.btrfs     # p4 裸 dump（sparse 7.8G）
```

## 用法

```bash
# 一键同步源树 → 工作副本 dArkOS3562_work.img (不存在时自动从基准 cp 创建)
sudo ./scripts/sync_image.sh
# 同步到指定镜像 (基准镜像本身禁止写入)
sudo ./scripts/sync_image.sh /path/xx.img
# 发布: 同步 + 清理首启状态 (.console 删除、extlinux 回 rg52mini) + 另存日期镜像
sudo ./scripts/sync_image.sh --release

# 手动挂载（在可 sudo 的终端执行；ZCode 沙箱不能 sudo）
sudo ./scripts/mount_arkos.sh mount ./dArkOS3562_work.img
#   -> ./mnt/{boot,root,roms}
sudo ./scripts/mount_arkos.sh unmount
```

基准镜像 `dArkOS_rg52mini_trixie_06242026.img` 是只读基准, 永不修改
(对齐 arkos4clone build_image.sh 的"源镜像不会被修改"原则)。

## 首启 / 开机机制

- `firstboot.service` 每次开机跑 `/boot/firstboot.sh`: **先执行 hook.sh**
  (机型检测/quirks/SDL2+SDL3 旋转库复制), 再跑 `expandtoexfat.sh` 扩容。
  hook 不再挂在扩容成功路径末尾 — 扩容超时被杀或 p5 已 exfat 都不影响
  SDL 复制。扩容收尾把 hook.sh 提升为 firstboot.sh。
- `expandtoexfat.sh`: p5 已 exfat **且** `/boot/fstab.exfat` 已删除才算完成
  (中途被杀的残留会重跑); 否则转 exFAT + 解包 roms.tar。
- 一镜像多设备: dtbselector 切 `extlinux/conf.d/<机型>.conf`, hook.sh 用
  console_detect 比较 FDT 与 `.console`, 变化即全量重应用 quirks。
- 发布镜像必须走 `--release`: 清掉工作副本测试启动留下的 `.console`,
  保证用户设备走完整首启。

## 引导 (开源 uboot, 必须)

原厂 uboot 无法引导我们的内核/设备树 — sync 时自动刷入开源构建。
来源: **~/AveyondFly-u-boot 的 rk3562 分支** (含关机充电修复、GPIO 时钟
修复、显示支持 CONFIG_DM_CHARGE_DISPLAY/DM_VIDEO), 构建方式:

```bash
cd ~/AveyondFly-u-boot   # 已检出 rk3562 分支
CROSS_COMPILE=/opt/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu- \
RKBIN=$HOME/rkbin ./build_uboot_rk3562.sh
cp build-rk3562/rk3562-uboot-16m.bin build-rk3562/manifest.txt ~/dArkOS/uboot/
```

产物 `uboot/rk3562-uboot-16m.bin` 由 flash_uboot.sh 一次 dd 写到 **sector 64**:

| blob 内位置 | 磁盘位置 | 内容 |
|---|---|---|
| +0 / +512KiB | sector 64 / 1088 | idblock 双份冗余 (DDR v1.10 + 自编 SPL) |
| blob sector 16320 | sector 16384 (p1, 4MiB) | FIT: ATF + OP-TEE + U-Boot (双份 2MiB) |

blob 结尾恰好到 16MiB (p3 起点), 不越界; p2 不动。校验清单见 `uboot/manifest.txt`。
单独刷写: `sudo ./uboot/flash_uboot.sh <img>` (基准镜像禁写)。

## WiFi 驱动 (无用户态服务)

全部 ko 在源树 `rootfs/usr/lib/modules/5.10.226/`, 随 sync 注入并 depmod:

| 模块 | 来源 | 设备 |
|---|---|---|
| extra/aic8800-usb/{aic_load_fw_usb,aic8800_fdrv_usb}.ko | kernel_rk3562 重编 | XF55H/NGP45HT (AIC8800DC USB) |
| extra/rk915/rk915.ko | kernel_rk3562 重编 (覆盖原厂) | RG52mini revA / RG43H/V (SDIO) |
| kernel/.../aic8800_{bsp,fdrv}.ko | 基准镜像原厂 (源码未改) | RG52mini revB (AIC8800DL SDIO) |

加载由 `hook.sh: load_wifi_modules` 每次开机顺序执行 (USB → rk915 → aic SDIO),
取代了 wifi-driver-load.service (sync 时 mask 原厂单元)。两个 SDIO 驱动 init
都会 pulse rockchip_wifi_power(), 不能并发 — `etc/modprobe.d/dArkOS-wifi.conf`
黑名单挡住 udev 自动加载, 显式 modprobe 不受影响。
注意: 树内 aic8800_fdrv 源码已换成 USB 专用新版, SDIO 变体无法从当前源码编出;
aic8800_bsp 与 USB loader 同导出 get_adap_test, 不能同场 modpost — 故 SDIO 栈
沿用原厂 ko。内核树 aic8800/Makefile 已相应注释 usb/ 与 aic8800_bsp/ 入口。

## 与 arkos4clone (H700) 的差异备忘

- 分区号后移：boot=p3、root=p4、roms=p5；p1/p2 是 uboot 区（不挂载；p1 刷开源 uboot FIT，p2 不动）
- root 为 **btrfs**（compress=zstd:1），rsync 注入时无需 e2fsck，校验用 `btrfs check`
- 平台 RK3562（非 H700），extlinux 引导，内核 `Image` + 单个 `rk3562-rg52mini.dtb`
- 用户单 `ark` uid=1000（相当于 arkos4clone 的 dArkOS 分支：777 / 1000:1000）
- `/home/ark/.config/retroarch{,32}` 双套 cores；`tempthemes` 仍存在（5 主题）
- `expandtoexfat.sh` 与 arkos4clone 版本**有差异**，同步时以本镜像版本为准或单独适配
