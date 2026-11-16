# dArkOS 3562

[中文](#中文) | [English](#english)

---

## 中文

### 项目简介

dArkOS 3562 是面向 RK3562 掌机的 Debian 游戏系统：以 EmulationStation 为前端，
集成 RetroArch 核心与多个独立模拟器，并提供掌机需要的按键映射、灯光、风扇、
电源与性能管理。

系统以**差异层**（diff layer）方式维护：仓库不保存完整镜像，只保存相对基线镜像
`dArkOS_rg52mini_trixie_06242026.img` 的改动。执行 `scripts/sync_image.sh`
即可在本地把差异层叠加到工作镜像，生成完整可刷写镜像。

- 一份镜像支持多台 RK3562 掌机，首次开机选择机型
- 基线镜像只读、永不修改，也不进仓库（约 12GB）
- 目标系统：Debian trixie (aarch64)、内核 5.10.226、Btrfs rootfs、exFAT ROM 分区
- 大于 100MB 的核心以 `.so.xz` 保存，构建时自动解压

### 支持的设备

| 品牌 | 机型 | DTB | 分辨率 | 菜单键 |
|---|---|---|---|---|
| AISLPC | RG52 Mini | `rk3562-rg52mini.dtb` | 1280x720 竖屏 | Home |
| AISLPC | RG43V Pro | `rk3562-rg43h.dtb` | 1024x768 | Select |
| AISLPC | RG43H Pro | `rk3562-rg43h.dtb` | 1024x768 | Select |
| AISLPC | Pocket AIS | `rk3562-ais.dtb` | 1024x768 | Home |
| XiFan | NGP45HT | `rk3562-ngp45ht.dtb` | 1024x768 | M |
| XiFan | XF55H | `rk3562-xf55h.dtb` | 1280x720 | M |

切换机型：首次开机用 **dtb 选择器**，PC 端可运行 `dtbtools/` 里的 dtbselector，
或手动修改 `/boot/extlinux/extlinux.conf` 的 `FDT`。首次开机 `hook.sh` 会按机型
应用 quirks（SDL 旋转库、按键映射等），并把 `/boot/hook.sh` 提升为
`/boot/firstboot.sh` 供后续每次启动使用。

操作约定：

- 大部分设备用 **Hotkey + X（或 Y）** 打开快捷菜单，Hotkey 即上表的菜单键
  （Select 也可作为 Hotkey）
- 大部分模拟器退出键为 **Start + Select**；RetroArch 请先打开快捷菜单再退出

### 模拟器与核心

#### 独立模拟器

| 平台 | 实现 | 说明 |
|---|---|---|
| PS2 | ARMSX2 | Vulkan + `malisx2`；BIOS 放 `/roms/ps2/bios`；`ps2.sh` 启动 |
| GameCube / Wii | Dolphin NoGUI | 默认 Vulkan，`VK_KHR_display` 直出 KMS；`dolphin.sh` |
| PS1 | DuckStation 官方 mini AppImage | 每机型热键；设置/存档放 ROM 分区；BIOS 放 `/roms/bios` |
| PSP | PPSSPP / PPSSPP 2021 | 两个版本可选，保留多后端 |
| NDS | DSperate / DraStic | DSperate 走系统 Vulkan + 中文界面；需要 NDS BIOS |
| Saturn | YabaSanshiro | 共 4 个版本；需要 BIOS |
| Dreamcast | Flycast 2.7 / Flycast 2022 | 两个版本均支持 Vulkan |
| PS Vita | Vita3K-Plus | 独立 Wayland 会话；运行库集中在 `/opt/vita3k` |
| J2ME | FreeJ2ME | 独立版，中文字体与手柄映射已内置 |
| Flash | Ruffle | — |
| 视觉小说 | KRKR2 / onsCripter | KRKR2 游戏放 `/roms/krkr2`；onsCripter 另有核心 |
| Pico-8 | Fake08 | — |
| N64 | mupen64plus | GLideN64 / Rice 插件，`n64.sh` 启动 |
| 通用运行器 | retrorun | 支持 Flycast 2021 / Flycast 2022 核心 |
| 视频 | Kodi | 支持 Rockchip MPP 硬件解码 |

#### libretro 核心

| 核心 | 说明 |
|---|---|
| 3DS（Azahar） | Vulkan + 自编 `malisx2` ICD；`azahar.sh` 启动 |
| armN64 | N64 备选核心 |
| parallel_n64 | 默认 GLES + Rice；另有 Vulkan 变体，手动启用 |
| parallel_dc | Dreamcast |
| armGBA | GBA / GB / GBC；同时提供 gambatte、mgba 等基线核心 |
| GPSP | 支持 EZODE 震动与 mGBA 金手指 |
| pcsx_rearmed | 带金手指版本，效率最高 |
| mame2015 / mame2016 / native32 | 街机 |
| yabadabadoo | Saturn |
| 其他基线核心 | 随镜像提供 |

### EmulationStation 功能

- 3562 入口，模拟器与核心按系统分组
- Wi-Fi 界面入口与 SSH 服务管理
- 显示设置：亮度、伽马、色温
- 摇杆设置：死区、用户态漂移校准、XBOX/NS 布局切换、关闭线性扳机上报
- 摇杆灯与电源灯管理
- batteryplus 服务开关
- 风扇控制（仅带风扇的机型）；任意界面可用 Hotkey + Start 开关风扇
- 性能设置：CPU / GPU / DMC 频率；可将 loader 写入 eMMC 解锁 DMC 1056
- ZRAM 管理：多种算法与大小，推荐 LZ4
- 模拟器切换在对应系统的 **SELECT** 菜单中完成；请先选择模拟器再选核心，
  否则核心列表为空
- 351Files：支持多种局域网无线传输协议、百度云上传/下载、双列显示与 root 进入

### 系统特性

- 关机状态下充电不会自动开机
- 关机充电时点亮红色 LED；由于没有充电动画，插入时用震动提示，充满后 LED 熄灭
- 电池驱动经过调整，电量显示更准确（关闭 batteryplus 时使用驱动数据）
- 支持长按音量键快速加减电量

### 启动与内核

- AveyondFly RK3562 开源 U-Boot（`uboot/rk3562-uboot-16m.bin`，16MB）
- 每机型独立 DTB / extlinux 配置；U-Boot 开机 logo 与关机充电动画
- 构建时写入品牌信息：plymouth `text.plymouth` 的标题改为 `dArkOS 3562 (YYYYMMDD)`，
  与镜像名同源
- 内核重编（Linaro 6.3.1 交叉工具链），含：
  - `rk3562-joystick`（`play_joystick`）：mV 死区、`axis_to_dpad`、
    `invert_abs*`、`swap_ab/swap_xy`、`swap_start_home`、`linear_triggers`、
    `joypad_tuning`（运行时校准）
  - 摇杆 RGB 灯驱动（`led-3562`）、风扇 PWM、RK817 电量/关机修复
  - Wi-Fi：AIC8800（USB/SDIO）、ZTop ZT9101（USB），按机型自动加载
  - zram、Kodi 的 Rockchip MPP 硬解
- **DMC/内存频率未做内核改动**：可用频点由 ATF（DDR 固件）通过
  `DRAM_GET_FREQ_INFO` 上报，内核按 DT 的 `system-status-level` 使用

### 目录结构

```
boot/      启动分区差异层（Image、hook.sh、DTB、extlinux）
rootfs/    rootfs 差异层（/usr/local/bin、/opt、ES 配置等）
uboot/     U-Boot 16MB blob 与刷写脚本
scripts/   sync_image.sh / mount_arkos.sh / CI 辅助脚本
dtbtools/  PC 端 DTB 选择工具
roms/      ROM 目录占位（实际内容在设备 SD 卡上）
.github/   CI 工作流
```

### ROM 放哪里

ROM 都在 SD 卡的 exFAT 分区（挂载点 `/roms`），按系统分目录：

```
/roms/3ds/     .3ds .cci .cxi .cia .3dsx .zip .7z
/roms/ps2/     .iso .chd .cso .bin .elf
/roms/gc/      .iso .gcm .rvz .wbfs
/roms/wii/     .iso .rvz .wbfs
/roms/psx/     .bin/.cue .chd .pbp
/roms/psp/     .iso .cso .chd .pbp
/roms/nds/     .nds .zip .7z
/roms/saturn/  .bin/.cue .chd
/roms/krkr2/   游戏目录
/roms/psvita/  .vpk / 已安装游戏
/roms/gba|gb|gbc/ ...
```

### BIOS / 系统文件放哪里

统一放在 **`/roms/bios/`**（RetroArch 的 system 目录、DuckStation、ARMSX2
的 `[Folders] Bios` 都指向这里）：

| 平台 | 需要的文件 | 放置位置 |
|---|---|---|
| PS1（DuckStation / PCSX ReARMed） | `SCPH1001.BIN`（美版）、`SCPH5500`（日版）、`SCPH5501`（美版）、`SCPH5502`（欧版） | `/roms/bios/` |
| PS2（ARMSX2） | 任意有效 PS2 BIOS dump，如 `scph39001.bin`、`SCPH-70012_BIOS_V12_USA_200.bin` | `/roms/ps2/bios/` |
| NDS（DSperate） | `nds_bios9.bin`、`nds_bios7.bin`、`nds_firmware.bin` | `/roms/bios/` |
| Saturn（YabaSanshiro） | `sega_101.bin`（日版）、`mpr-17933.bin`（美/欧版） | `/roms/bios/` |
| Dreamcast（Flycast） | `dc_boot.bin`、`dc_flash.bin`（可选） | `/roms/bios/` |
| PS Vita（Vita3K） | 通过 Vita3K 界面导入系统固件 | Vita3K 自管 |
| PCE CD / Sega CD 等光驱机种 | 对应核心要求的 BIOS | `/roms/bios/` |
| GBA（armGBA） | **不需要 BIOS** | — |
| 3DS（Azahar） | 游戏不需要 BIOS；部分游戏需要 3DS 系统文件，通过 Azahar 自身导入 | Azahar 自管 |
| N64 / SNES / MD 等卡带机种 | **不需要 BIOS** | — |

注意：

- `SCPH1001.BIN` 是 PS1 BIOS，**PS2 不能使用**
- PS2 没有 BIOS 时 ARMSX2 只能进主界面，无法启动游戏
- BIOS 文件名通常不强制，但大小/内容必须是正确 dump（模拟器按内容识别）

### 构建

```bash
# 依赖：sudo、losetup、rsync、btrfs-progs、exfatprogs、7z、xz、parted
# 把基线镜像放到仓库根目录，文件名必须是：
#   dArkOS_rg52mini_trixie_06242026.img

sudo ./scripts/sync_image.sh --release
```

产物：

```
dArkOS3562_YYYYMMDD.img
dArkOS3562_YYYYMMDD.img.sha256
```

- 镜像名使用构建日期（`YYYYMMDD`），同时写入 plymouth 标题 `dArkOS 3562 (YYYYMMDD)`
- 需要复现某一版时：`DARKOS_BUILD_DATE=20261116 sudo ./scripts/sync_image.sh --release`
- `--release` 清掉工作副本的首启状态并重置 extlinux，保证新卡走完整首启流程；
  `--ci` 原地清理，不复制 12GB 镜像

### 烧录与首次开机

- 用 dd / balenaEtcher 等把 `.img` 写入 SD 卡
- 首次启动会扩容并重新格式化 ROM 分区，**刷机前请备份 ROM / BIOS / 存档**
- 首次启动执行 hook + 扩容后自动重启一次，第二次启动进入 ES
- 进 ES 后选择机型（dtb）、连接 Wi-Fi；镜像不保存 Wi-Fi 密码

### 云端 CI

`.github/workflows/build-image.yml` 手动触发：

- 基线镜像默认从 `bmdhacks/dArkOS_rg52mini` v06242026 的
  `.7z.001/.002/.003` 下载（可用输入框或仓库变量 `DARKOS_BASE_URL` 覆盖）
- `publish=true`：创建 draft Release（tag `dArkOS-YYYYMMDD`）并上传产物
- `publish=false`：仅保存为 workflow artifact
- 产物为 `dArkOS3562_YYYYMMDD.img.xz`，超过 1900MiB 自动 7z 分卷

### 说明

- 内存/DDR 频率由 ATF 与 DDR 固件决定，本项目不做内核覆盖
- DuckStation 受协议限制只内置官方 AppImage
- 不提供任何商业 ROM/BIOS 文件

---

## English

### Overview

dArkOS 3562 is a Debian-based gaming system for RK3562 handhelds. EmulationStation
is the frontend; it integrates libretro cores and several standalone emulators,
and adds the handheld-specific pieces: button mapping, LEDs, fan, power and
performance management.

The system is maintained as a **diff layer**: the repository does not store a
full image, only the changes on top of the read-only baseline
`dArkOS_rg52mini_trixie_06242026.img`. Running `scripts/sync_image.sh` overlays
those changes onto a work image and produces a complete, flashable image.

- One image supports all listed RK3562 handhelds; the model is selected on first boot.
- The baseline image is read-only and never stored in the repository (~12 GB).
- Target: Debian trixie (aarch64), kernel 5.10.226, Btrfs rootfs, exFAT ROM partition.
- Cores larger than 100 MB are stored as `.so.xz` and expanded during the build.

### Supported devices

| Brand | Device | DTB | Resolution | Menu key |
|---|---|---|---|---|
| AISLPC | RG52 Mini | `rk3562-rg52mini.dtb` | 1280x720 portrait | Home |
| AISLPC | RG43V Pro | `rk3562-rg43h.dtb` | 1024x768 | Select |
| AISLPC | RG43H Pro | `rk3562-rg43h.dtb` | 1024x768 | Select |
| AISLPC | Pocket AIS | `rk3562-ais.dtb` | 1024x768 | Home |
| XiFan | NGP45HT | `rk3562-ngp45ht.dtb` | 1024x768 | M |
| XiFan | XF55H | `rk3562-xf55h.dtb` | 1280x720 | M |

Switching models: use the **DTB selector** on first boot, run the PC-side
dtbselector in `dtbtools/`, or edit `FDT` in `/boot/extlinux/extlinux.conf`.
On first boot `hook.sh` applies per-model quirks (SDL rotation, button mapping)
and promotes itself to `/boot/firstboot.sh` for every subsequent boot.

Controls:

- **Hotkey + X (or Y)** opens the quick menu on most devices, where Hotkey is
  the menu key above (Select also works as Hotkey).
- Most emulators quit with **Start + Select**; in RetroArch, open the quick menu
  first and exit from there.

### Emulators and cores

#### Standalone emulators

| Platform | Implementation | Notes |
|---|---|---|
| PS2 | ARMSX2 | Vulkan + `malisx2`; BIOS in `/roms/ps2/bios`; launched by `ps2.sh` |
| GameCube / Wii | Dolphin NoGUI | Vulkan by default, `VK_KHR_display` direct to KMS; `dolphin.sh` |
| PS1 | DuckStation official mini AppImage | per-model hotkeys; settings/saves on the ROM partition; BIOS in `/roms/bios` |
| PSP | PPSSPP / PPSSPP 2021 | two builds, multiple backends |
| NDS | DSperate / DraStic | DSperate uses system Vulkan with a Chinese UI; NDS BIOS required |
| Saturn | YabaSanshiro | four builds; BIOS required |
| Dreamcast | Flycast 2.7 / Flycast 2022 | both support Vulkan |
| PS Vita | Vita3K-Plus | dedicated Wayland session; runtime files under `/opt/vita3k` |
| J2ME | FreeJ2ME | standalone build with bundled CJK font and pad mapping |
| Flash | Ruffle | — |
| Visual novels | KRKR2 / onsCripter | KRKR2 games in `/roms/krkr2`; onsCripter also ships a core |
| Pico-8 | Fake08 | — |
| N64 | mupen64plus | GLideN64 / Rice plugins; launched by `n64.sh` |
| Runner | retrorun | supports the Flycast 2021 and Flycast 2022 cores |
| Video | Kodi | Rockchip MPP hardware decoding |

#### libretro cores

| Core | Notes |
|---|---|
| 3DS (Azahar) | Vulkan + self-built `malisx2` ICD; launched by `azahar.sh` |
| armN64 | alternative N64 core |
| parallel_n64 | defaults to GLES + Rice; a Vulkan variant is available for manual use |
| parallel_dc | Dreamcast |
| armGBA | GBA / GB / GBC; gambatte and mgba baseline cores are also included |
| GPSP | EZODE rumble and mGBA cheat support |
| pcsx_rearmed | cheat-enabled build, the most efficient PS1 option |
| mame2015 / mame2016 / native32 | arcade |
| yabadabadoo | Saturn |
| Other baseline cores | shipped with the image |

### EmulationStation features

- RK3562 entry; emulators and cores grouped per system.
- Wi-Fi UI and SSH service management.
- Display settings: brightness, gamma, color temperature.
- Stick settings: deadzone, user-space drift calibration, XBOX/NS layout switch,
  optional linear-trigger reporting.
- Stick LED and power LED management.
- batteryplus service toggle.
- Fan control (fan-equipped models only); Hotkey + Start toggles it from any screen.
- Performance settings: CPU / GPU / DMC clocks; write the loader to eMMC to
  unlock DMC 1056.
- ZRAM management with multiple algorithms and sizes; LZ4 is recommended.
- Emulator switching lives in each system's **SELECT** menu; choose the emulator
  before the core, otherwise the core list is empty.
- 351Files: multiple LAN/wireless transfer protocols, Baidu Cloud upload/download,
  dual-pane view and root access.

### System features

- Charging while powered off does not boot the device.
- A red LED lights up while charging with the device off; there is no charging
  animation, so the device vibrates when charging starts, and the LED turns off
  when fully charged.
- The battery driver is tuned for more accurate readings (driver data is used
  when batteryplus is disabled).
- Long-press the volume keys to quickly raise or lower the battery level.

### Boot and kernel

- AveyondFly RK3562 open-source U-Boot (`uboot/rk3562-uboot-16m.bin`, 16 MB).
- Per-model DTB / extlinux configuration; U-Boot boot logo and shutdown-charging animation.
- The build writes the brand into the plymouth title: `text.plymouth` becomes
  `dArkOS 3562 (YYYYMMDD)`, matching the image name.
- Kernel rebuilt with the Linaro 6.3.1 cross toolchain, including:
  - `rk3562-joystick` (`play_joystick`): mV deadzone, `axis_to_dpad`,
    `invert_abs*`, `swap_ab/swap_xy`, `swap_start_home`, `linear_triggers`,
    `joypad_tuning` (runtime calibration)
  - stick RGB LED driver (`led-3562`), fan PWM, RK817 battery/shutdown fixes
  - Wi-Fi: AIC8800 (USB/SDIO) and ZTop ZT9101 (USB), loaded automatically per model
  - zram, Rockchip MPP hardware decoding for Kodi
- **No kernel changes for DMC/memory frequency**: available points are reported by
  ATF (DDR firmware) through `DRAM_GET_FREQ_INFO`, and the kernel selects them via
  the DT `system-status-level`.

### Directory layout

```
boot/      boot-partition diff layer (Image, hook.sh, DTB, extlinux)
rootfs/    rootfs diff layer (/usr/local/bin, /opt, ES config, ...)
uboot/     U-Boot 16 MB blob and flashing scripts
scripts/   sync_image.sh / mount_arkos.sh / CI helpers
dtbtools/  PC-side DTB selection tool
roms/      ROM directory placeholders (real content lives on the SD card)
.github/   CI workflows
```

### Where ROMs go

ROMs live on the SD card's exFAT partition (mounted at `/roms`), one directory
per system:

```
/roms/3ds/     .3ds .cci .cxi .cia .3dsx .zip .7z
/roms/ps2/     .iso .chd .cso .bin .elf
/roms/gc/      .iso .gcm .rvz .wbfs
/roms/wii/     .iso .rvz .wbfs
/roms/psx/     .bin/.cue .chd .pbp
/roms/psp/     .iso .cso .chd .pbp
/roms/nds/     .nds .zip .7z
/roms/saturn/  .bin/.cue .chd
/roms/krkr2/   game directories
/roms/psvita/  .vpk / installed games
/roms/gba|gb|gbc/ ...
```

### Where BIOS / system files go

Everything goes in **`/roms/bios/`** (RetroArch's system directory, DuckStation,
and ARMSX2's `[Folders] Bios` all point here):

| Platform | Required files | Location |
|---|---|---|
| PS1 (DuckStation / PCSX ReARMed) | `SCPH1001.BIN` (US), `SCPH5500` (JP), `SCPH5501` (US), `SCPH5502` (EU) | `/roms/bios/` |
| PS2 (ARMSX2) | any valid PS2 BIOS dump, e.g. `scph39001.bin`, `SCPH-70012_BIOS_V12_USA_200.bin` | `/roms/ps2/bios/` |
| NDS (DSperate) | `nds_bios9.bin`, `nds_bios7.bin`, `nds_firmware.bin` | `/roms/bios/` |
| Saturn (YabaSanshiro) | `sega_101.bin` (JP), `mpr-17933.bin` (US/EU) | `/roms/bios/` |
| Dreamcast (Flycast) | `dc_boot.bin`, `dc_flash.bin` (optional) | `/roms/bios/` |
| PS Vita (Vita3K) | import system firmware through the Vita3K UI | managed by Vita3K |
| PCE CD / Sega CD and other CD-based systems | the BIOS required by the core | `/roms/bios/` |
| GBA (armGBA) | **no BIOS needed** | — |
| 3DS (Azahar) | no BIOS for games; some games need 3DS system files, imported through Azahar | managed by Azahar |
| N64 / SNES / MD and other cartridge systems | **no BIOS needed** | — |

Notes:

- `SCPH1001.BIN` is a PS1 BIOS and **cannot be used for PS2**.
- Without a PS2 BIOS, ARMSX2 can only reach its main menu, not boot games.
- BIOS file names are usually not enforced, but the size and content must be a
  correct dump (emulators identify files by content).

### Build

```bash
# deps: sudo, losetup, rsync, btrfs-progs, exfatprogs, 7z, xz, parted
# place the baseline image at the repository root as:
#   dArkOS_rg52mini_trixie_06242026.img

sudo ./scripts/sync_image.sh --release
```

Output:

```
dArkOS3562_YYYYMMDD.img
dArkOS3562_YYYYMMDD.img.sha256
```

- The image name uses the build date (`YYYYMMDD`), and the same date is written
  into the plymouth title `dArkOS 3562 (YYYYMMDD)`.
- Reproduce a specific build with:
  `DARKOS_BUILD_DATE=20261116 sudo ./scripts/sync_image.sh --release`
- `--release` clears first-boot state from the work copy and resets extlinux so a
  new card runs the full first-boot flow; `--ci` cleans in place without copying
  the 12 GB image.

### Flashing and first boot

- Write the `.img` to an SD card with dd or balenaEtcher.
- The first boot expands and reformats the ROM partition, **so back up ROM /
  BIOS / saves before flashing**.
- The first boot runs hook + expansion and reboots once; the second boot starts ES.
- In ES, select the device model (DTB) and join Wi-Fi. Wi-Fi passwords are not
  stored in the image.

### CI

`.github/workflows/build-image.yml` is triggered manually:

- The baseline is downloaded from the `bmdhacks/dArkOS_rg52mini` v06242026
  `.7z.001/.002/.003` parts by default (overridable via the input field or the
  repository variable `DARKOS_BASE_URL`).
- `publish=true`: create a draft Release (tag `dArkOS-YYYYMMDD`) and upload artifacts.
- `publish=false`: store as a workflow artifact only.
- The artifact is `dArkOS3562_YYYYMMDD.img.xz`; anything over 1900 MiB is split
  into 7z volumes automatically.

### Notes

- Memory/DDR frequency is controlled by ATF and the DDR firmware; this project
  does not override it in the kernel.
- DuckStation is limited to the official AppImage build for licensing reasons.
- No commercial ROM or BIOS files are included.
