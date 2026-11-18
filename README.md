# dArkOS 3562

[中文](#中文) | [English](#english)

---

## 中文

### 项目说明

dArkOS 3562 是面向 RK3562 掌机的**差异层**（diff layer）仓库：可刷写镜像由基线镜像
`dArkOS_rg52mini_trixie_06242026.img`（Debian trixie / aarch64、内核 5.10.226、
Btrfs rootfs、exFAT ROM 分区）叠加本仓库的 `boot/` 与 `rootfs/` 得到。基线镜像只读、
不进仓库；`scripts/sync_image.sh` 负责生成工作副本与发布镜像。

本文描述**相对基线的改动与新增**。

### 致谢

- [christianhaitian/dArkOS](https://github.com/christianhaitian/dArkOS/)
- [bmdhacks/dArkOS_rg52mini](https://github.com/bmdhacks/dArkOS_rg52mini)

---

## 版本预览

### 1. 设备支持

镜像刷入后使用 **dtb 选择器**可切换设备：

| 品牌 | 机型 | 菜单热键 |
|---|---|---|
| AISLPC | RG52 Mini | Home |
| AISLPC | RG43V | Select |
| AISLPC | RG43H | Select |
| AISLPC | Pocket AIS | Home |
| XiFan | NGP45HT | M |
| XiFan | XF55H | M |

- 大部分设备用 **hotkey + X（Y）** 打开快捷菜单，hotkey 为上表括号/列中的按键
- 大部分模拟器退出快捷键为 **Start + Select**；RetroArch 请先打开快捷菜单再退出

### 2. 模拟器新增

- **2.1 PS2 / ARMSX2（新增）**：默认 Vulkan，BIOS 放 `/roms/bios`；**hotkey + Y 打开菜单**
- **2.2 Wii / NGC / Dolphin（新增）**：默认 Vulkan，游戏放 `/roms/wii`、`/roms/gc`；**Start + Select 退出**
- **2.3 NDS / DSperate（新增）**：**Select + Y 打开菜单**；优化中文字体显示，支持 Vulkan 渲染
- **2.4 Fake08（更新）**
- **2.5 Flycast 2.7（更新）**：支持 Vulkan；**Select 打开菜单**
- **2.6 Flycast 2022（新增）**：支持 Vulkan；**Select 打开菜单**
- **2.7 KRKR2（新增）**：游戏放 `/roms/krkr2`；左摇杆移动光标，**A 为鼠标点击**
- **2.8 mupen64plus（更新）**：所有组件更新
- **2.9 onscripter（新增）**：独立模拟器 + 核心
- **2.10 PPSSPP / PPSSPP 2021（更新）**：均支持 Vulkan；**L3 / Mode 打开菜单**
- **2.11 YabaSanshiro（更新）**：共 4 个版本；**Select 打开菜单**
- **2.12 PS Vita / Vita3K（新增）**
- **2.13 Flash / Ruffle（新增）**
- **2.14 retrorun（更新）**：支持 Flycast 2022 / Flycast 2021 核心；**按住 Select + Start 退出**
- **2.15 DuckStation（更新）**：因协议限制只内置官方版本，BIOS 放 `/roms/bios`
  - hotkey + X（手柄标 Y）打开菜单
  - hotkey + L2 即时读档；hotkey + R2 即时存档；hotkey + L1 快进
- **2.16 Kodi（更新）**：支持硬件解码视频（Rockchip MPP）
- **2.17 FreeJ2ME（新增）**：独立模拟器；**Select + X 打开菜单**
- **2.18 OpenBOR LNS（新增）**：AveyondFly 的新构建，与 OpenBOR 在同一系统内切换
- **2.19 RetroArch（更新）**：更新到 2026 年 11 月版本，支持 Vulkan，并修复 Vulkan 旋转下快捷菜单错乱
  - hotkey + X 打开菜单；hotkey + Y 显示帧率
  - hotkey + L 回溯（默认关闭）；hotkey + R 快进
  - hotkey + L2 读取存档；hotkey + R2 保存存档

### 3. 核心新增

- **3.1 ArmN64（新增）**：核心选项全汉化
- **3.2 Parallel N64（更新）**：核心选项全汉化
- **3.3 3DS / Azahar（新增）**：支持 Vulkan，核心选项全汉化；游戏内可用 **hotkey + A** 切换布局，快捷键（ABXY）可在核心选项中修改
- **3.4 GPSP（新增）**：支持 EZODE 震动与 mGBA 金手指，核心选项全汉化
- **3.5 mame2015 / mame2016 / native32（新增）**
- **3.6 YabaSanshiro 土星核心（新增）**：核心选项全汉化
- **3.7 Parallel N64 Vulkan（新增）**：核心选项全汉化
- **3.8 Parallel DC（新增）**：核心选项全汉化
- **3.9 pcsx_rearmed（更新）**：带金手指版本，BIOS 自动加载（读取游戏同名 `.BIOS`），效率最高，核心选项全汉化
- **3.10 ArmGBA（新增）**：效率高于 GPSP，移植 EZODE 震动，核心选项全汉化
- **3.11 全部 PCE 核心（更新）**：BIOS 自动加载（读取游戏同名 `.BIOS`），核心选项全汉化
- **3.12 NES / SNES / MD 等核心（更新）**：全部回到上游最新源码重编，核心选项补全汉化，64 位 + 32 位
- **3.13 XBOX / hakuX（新增）**：支持 Vulkan，核心选项全汉化（读取 `.iso` / `.chd`，需 64 位 RetroArch + Vulkan）
- **3.14 Mesen CE（新增）**：NES / FDS / SNES / GB / GBC / GBA / PCE / SMS / GG / WonderSwan，核心选项中文，64 位 + 32 位

### 4. EmulationStation 功能添加

- **4.1** 新增 3562 入口
- **4.2** 集成 Wi-Fi 界面入口以及 SSH 服务管理
- **4.3** 新增显示界面：亮度、伽马、色温
- **4.4** 新增摇杆设定入口：死区、用户态摇杆漂移校准、XBOX/NS 布局切换、关闭线性扳机上报
- **4.5** 新增摇杆灯与电源灯管理
- **4.6** 新增 batteryplus 服务，可自行选择开关
- **4.7** 新增风扇控制入口（仅带风扇设备），任意界面可用 **hotkey + Start** 切换开关
- **4.8** 新增性能设置入口：CPU / GPU / DMC 频率。默认 TF 卡系统 DMC 为 920M；AISLPC 的 DMC 限制 800，XiFan 限制 1056。芯片默认安全上限为 920，AISLPC 需先把 Loader 写入 eMMC 才能使用 920M；同时提供 Loader 更新入口
- **4.9** 新增 ZRAM 管理：多种算法、多种大小缓解内存压力，推荐 LZ4
- **4.10** 模拟器切换移到对应模拟器界面按 **SELECT** 打开；选择核心前请先选择模拟器，否则核心为空
- **4.11** 外接 USB Wi-Fi：Wi-Fi 列表内可在多个无线网口（内置 wlan0 / USB 网卡）之间切换，切换后按所选网口扫描与连接

### 5. 系统调整

- **5.1** 关闭状态下充电不会直接开机
- **5.2** 关闭状态下充电亮红色 LED；由于没有充电动画，用震动提示进入充电，充满后熄灭
- **5.3** 调整电池驱动，电量更准确（不要开 batteryplus 服务时走驱动数据）
- **5.4** 允许长按音量键快速加减电量
- **5.5** 更新 ogage 全局快捷键：
  - hotkey + 左：减少音量
  - hotkey + 右：增加音量
  - hotkey + 上：增加亮度
  - hotkey + 下：减少亮度
  - hotkey + Start：切换风扇 开/关
- **5.6** 增强 351Files：支持更多局域网无线传输协议，支持从百度云上传/下载，支持双列显示，支持 root 用户进入

---

### 构建

```bash
# 依赖：sudo、losetup、rsync、btrfs-progs、exfatprogs、parted、dosfstools、gdisk、7z、xz
# 基线镜像放仓库根目录，文件名固定：
#   dArkOS_rg52mini_trixie_06242026.img

sudo ./scripts/sync_image.sh --release
```

流程：刷 U-Boot → 构建期分区定尺（boot 256MiB / rootfs 11264MiB / ROM 占位）→ 挂载 →
同步 boot/rootfs → 打包 roms.tar → depmod → 清理首启状态 → 输出
`dArkOS3562_YYYYMMDD.img` 与 `.sha256`。`DARKOS_BUILD_DATE=YYYYMMDD` 可复现日期；
`--ci` 原地构建，不复制 12GB 镜像。

### 烧录与首次开机

- 用 dd / balenaEtcher 写入 SD 卡；**首启会重建 ROM 分区，刷机前备份 ROM/BIOS/存档**
- 首启：hook 应用机型 quirks → ROM 分区重建为 exFAT 并解包 roms.tar → 自动重启，
  第二次启动进入 ES；在 ES 中选择机型、连接 Wi-Fi（镜像不保存 Wi-Fi 密码）

### 目录结构

```
boot/      启动分区差异层（Image、hook.sh、DTB、extlinux）
rootfs/    rootfs 差异层（/usr/local/bin、/opt、ES 配置等）
uboot/     U-Boot 16MB blob 与刷写脚本
scripts/   sync_image.sh / repart_image.sh / mount_arkos.sh / CI 辅助
dtbtools/  PC 端 DTB 选择工具
roms/      ROM 目录占位（实际 ROM 在设备 SD 卡）
.github/   CI 工作流
```

---

## English

### About

dArkOS 3562 is a **diff-layer** repository for RK3562 handhelds: the flashable image is
the baseline `dArkOS_rg52mini_trixie_06242026.img` (Debian trixie / aarch64, kernel
5.10.226, Btrfs rootfs, exFAT ROM partition) with this repository's `boot/` and
`rootfs/` overlaid. The baseline stays read-only and is never stored here;
`scripts/sync_image.sh` builds the work copy and the release image.

This document describes the **changes and additions on top of the baseline**.

### Credits

- [christianhaitian/dArkOS](https://github.com/christianhaitian/dArkOS/)
- [bmdhacks/dArkOS_rg52mini](https://github.com/bmdhacks/dArkOS_rg52mini)

---

## Release highlights

### 1. Device support

After flashing, use the **DTB selector** to switch models:

| Brand | Model | Menu hotkey |
|---|---|---|
| AISLPC | RG52 Mini | Home |
| AISLPC | RG43V | Select |
| AISLPC | RG43H | Select |
| AISLPC | Pocket AIS | Home |
| XiFan | NGP45HT | M |
| XiFan | XF55H | M |

- On most devices **hotkey + X (Y)** opens the quick menu; hotkey is the key listed above
- Most emulators exit with **Start + Select**; in RetroArch open the quick menu and quit

### 2. Emulators added

- **2.1 PS2 / ARMSX2 (new)**: Vulkan by default, BIOS in `/roms/bios`; **hotkey + Y opens the menu**
- **2.2 Wii / GameCube / Dolphin (new)**: Vulkan by default, games in `/roms/wii`, `/roms/gc`; **Start + Select exits**
- **2.3 NDS / DSperate (new)**: **Select + Y opens the menu**; improved Chinese font rendering, Vulkan rendering
- **2.4 Fake08 (updated)**
- **2.5 Flycast 2.7 (updated)**: Vulkan support; **Select opens the menu**
- **2.6 Flycast 2022 (new)**: Vulkan support; **Select opens the menu**
- **2.7 KRKR2 (new)**: games in `/roms/krkr2`; left stick moves the cursor, **A clicks**
- **2.8 mupen64plus (updated)**: all components updated
- **2.9 onscripter (new)**: standalone emulator plus a libretro core
- **2.10 PPSSPP / PPSSPP 2021 (updated)**: both support Vulkan; **L3 / Mode opens the menu**
- **2.11 YabaSanshiro (updated)**: four builds; **Select opens the menu**
- **2.12 PS Vita / Vita3K (new)**
- **2.13 Flash / Ruffle (new)**
- **2.14 retrorun (updated)**: supports the Flycast 2022 / Flycast 2021 cores; **hold Select + Start to exit**
- **2.15 DuckStation (updated)**: official build only for licensing reasons, BIOS in `/roms/bios`
  - hotkey + X (labelled Y on the pad) opens the menu
  - hotkey + L2 load state; hotkey + R2 save state; hotkey + L1 fast forward
- **2.16 Kodi (updated)**: hardware video decoding (Rockchip MPP)
- **2.17 FreeJ2ME (new)**: standalone emulator; **Select + X opens the menu**
- **2.18 OpenBOR LNS (new)**: new AveyondFly build, switchable with OpenBOR inside one system
- **2.19 RetroArch (updated)**: updated to the November 2026 build with Vulkan support, and the quick menu no longer corrupts under rotated Vulkan
  - hotkey + X opens the menu; hotkey + Y toggles the FPS display
  - hotkey + L rewind (off by default); hotkey + R fast forward
  - hotkey + L2 load state; hotkey + R2 save state

### 3. Cores added

- **3.1 ArmN64 (new)**: fully localized core options
- **3.2 Parallel N64 (updated)**: fully localized core options
- **3.3 3DS / Azahar (new)**: Vulkan support, fully localized core options; **hotkey + A** switches the layout in game, and the shortcut (ABXY) is configurable in the core options
- **3.4 GPSP (new)**: EZODE rumble and mGBA cheats, fully localized core options
- **3.5 mame2015 / mame2016 / native32 (new)**
- **3.6 YabaSanshiro Saturn core (new)**: fully localized core options
- **3.7 Parallel N64 Vulkan (new)**: fully localized core options
- **3.8 Parallel DC (new)**: fully localized core options
- **3.9 pcsx_rearmed (updated)**: cheat-enabled build, automatic BIOS loading (reads a `.BIOS` file with the same name as the game), the most efficient option, fully localized core options
- **3.10 ArmGBA (new)**: faster than GPSP, EZODE rumble ported, fully localized core options
- **3.11 All PCE cores (updated)**: automatic BIOS loading (same-name `.BIOS`), fully localized core options
- **3.12 NES / SNES / MD and related cores (updated)**: rebuilt from the latest upstream sources, complete Chinese core options, 64-bit and 32-bit
- **3.13 XBOX / hakuX (new)**: Vulkan support, fully localized core options (`.iso` / `.chd`, needs 64-bit RetroArch with Vulkan)
- **3.14 Mesen CE (new)**: NES / FDS / SNES / GB / GBC / GBA / PCE / SMS / GG / WonderSwan, Chinese core options, 64-bit and 32-bit

### 4. EmulationStation additions

- **4.1** New 3562 entry
- **4.2** Wi-Fi UI entry and SSH service management
- **4.3** Display settings: brightness, gamma, color temperature
- **4.4** Stick settings: deadzone, user-space drift calibration, XBOX/NS layout switch, disable linear trigger reporting
- **4.5** Stick LED and power LED management
- **4.6** batteryplus service toggle
- **4.7** Fan control entry (fan-equipped models only); **hotkey + Start** toggles it from any screen
- **4.8** Performance settings: CPU / GPU / DMC clocks. The default TF-card system runs DMC at 920M; AISLPC caps it at 800 and XiFan at 1056. The chip's stock safe limit is 920, and AISLPC needs the loader written to eMMC before 920M can be used; a loader update entry is provided as well
- **4.9** ZRAM management: several algorithms and sizes to relieve memory pressure (LZ4 recommended)
- **4.10** Emulator switching moved into each system's **SELECT** menu; choose the emulator before the core, otherwise the core list is empty
- **4.11** External USB Wi-Fi: the Wi-Fi list can switch between wireless interfaces (built-in wlan0 / USB adapter), and scans and connects on the selected one

### 5. System changes

- **5.1** Charging while powered off does not boot the device
- **5.2** A red LED lights up while charging with the device off; there is no charging animation, so the device vibrates when charging starts and the LED turns off when full
- **5.3** Battery driver tuned for more accurate readings (driver data is used when batteryplus is off)
- **5.4** Long-press the volume keys to change the battery level quickly
- **5.5** Updated ogage global hotkeys:
  - hotkey + Left: volume down
  - hotkey + Right: volume up
  - hotkey + Up: brightness up
  - hotkey + Down: brightness down
  - hotkey + Start: toggle the fan on/off
- **5.6** Enhanced 351Files: more LAN/wireless transfer protocols, Baidu Cloud upload/download, dual-pane view, and root access

---

### Build

```bash
# deps: sudo, losetup, rsync, btrfs-progs, exfatprogs, parted, dosfstools, gdisk, 7z, xz
# the baseline must be at the repository root:
#   dArkOS_rg52mini_trixie_06242026.img

sudo ./scripts/sync_image.sh --release
```

Pipeline: flash U-Boot → build-time partitioning (boot 256 MiB / rootfs 11264 MiB / ROM
placeholder) → mount → sync boot/rootfs → pack roms.tar → depmod → clear first-boot
state → write `dArkOS3562_YYYYMMDD.img` and `.sha256`. Use
`DARKOS_BUILD_DATE=YYYYMMDD` to reproduce a date; `--ci` builds in place without copying
the 12 GB image.

### Flashing and first boot

- Write the image with dd or balenaEtcher; **the first boot rebuilds the ROM partition, so back up ROMs/BIOS/saves first**
- First boot: hook applies model quirks → ROM partition rebuilt as exFAT and roms.tar unpacked → automatic reboot; the second boot starts ES. Select the model and join Wi-Fi there (the image stores no Wi-Fi passwords)

### Directory layout

```
boot/      boot-partition diff layer (Image, hook.sh, DTB, extlinux)
rootfs/    rootfs diff layer (/usr/local/bin, /opt, ES config, ...)
uboot/     U-Boot 16 MB blob and flashing script
scripts/   sync_image.sh / repart_image.sh / mount_arkos.sh / CI helpers
dtbtools/  PC-side DTB selection tool
roms/      ROM directory placeholders (real ROMs live on the SD card)
.github/   CI workflows
```
