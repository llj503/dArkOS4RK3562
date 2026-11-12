# dArkOS for RK3562

[中文](#中文) | [English](#english)

---

## 中文

### 这是什么

dArkOS for RK3562 是构建在只读基线镜像 `dArkOS_rg52mini_trixie_06242026.img`
之上的**差异层**（diff layer）：仓库里只放我们改过/新增的文件，
由 `scripts/sync_image.sh` 同步进工作镜像并生成可刷写的完整镜像。

- 基线镜像**永不修改**，也不进仓库（约 12GB）
- 同一镜像通过 U-Boot / DTB 选择支持多台 RK3562 掌机
- 目标系统：Debian trixie (aarch64)、内核 5.10.226、Btrfs rootfs、exFAT ROM 分区

### 支持的机型

| 机型 | DTB | 分辨率 | 备注 |
|---|---|---|---|
| NGP45HT | `rk3562-ngp45ht.dtb` | 1024x768 | 本仓库主要开发/验证机 |
| RG52 Mini | `rk3562-rg52mini.dtb` | 640x480 竖屏 | 需 90° 旋转 |
| RG43H Pro | `rk3562-rg43h.dtb` | 640x480 竖屏 | 可选 RG43V 变体 |
| RG43V Pro | `rk3562-rg43h.dtb` | 640x480 竖屏 | FN 键 + 左摇杆极性不同 |
| XF55H | `rk3562-xf55h.dtb` | 640x480 竖屏 | ZT9101 USB Wi-Fi |
| Pocket AIS | `rk3562-ais.dtb` | — | SDIO Wi-Fi |

切换机型：PC 端运行 `dtbtools/` 里的 dtbselector（或 `boot/dtbselector_*`），
或手动修改 `/boot/extlinux/extlinux.conf` 的 `FDT`。首次开机 `hook.sh` 会按机型
应用 quirks（SDL 旋转库、按键映射等），并把 `/boot/hook.sh` 提升为
`/boot/firstboot.sh` 供后续每次启动使用。

### 相对基线镜像新增/修改的内容

**启动与内核**

- AveyondFly RK3562 开源 U-Boot（`uboot/rk3562-uboot-16m.bin`，16MB）
- 每机型独立 DTB / extlinux 配置；dArkOS 开机 logo 与关机充电动画
- 内核重编（Linaro 6.3.1 交叉工具链），含：
  - `rk3562-joystick`（`play_joystick`）：mV 死区、`axis_to_dpad`、
    `invert_abs*`、`swap_ab/swap_xy`、`swap_start_home`、`linear_triggers`、
    `joypad_tuning`（运行时校准）
  - 摇杆 RGB 灯驱动（`led-3562`）、风扇 PWM、RK817 电量/关机修复
  - Wi-Fi：AIC8800（USB/SDIO）、ZTop ZT9101（USB），按机型自动加载
  - zram、Kodi 的 Rockchip MPP 硬解
- **DMC/内存频率未做内核改动**：可用频点由 ATF（DDR 固件）通过
  `DRAM_GET_FREQ_INFO` 上报，内核按 DT 的 `system-status-level` 使用，
  不再有任何 `clamp_normal` 之类的覆盖参数

**EmulationStation（fcamod）**

- 重新编译，中英文完整本地化
- 摇杆设置：死区（`adc_deadzone`，预设 32/64/128/256/384/512/768 mV，
  自定义 10–1800，0=DT 默认）、交换 A/B、交换 X/Y、线性扳机上报开关、摇杆校准
- 硬件菜单：摇杆灯、电源灯、风扇控制、BATTERYPLUS、ZRAM、DMC 最高频率
- 新增系统：Nintendo 3DS、PlayStation 2、GameCube、Wii
- **已移除 PS Vita / Vita3K 支持**

**模拟器**

| 平台 | 实现 | 说明 |
|---|---|---|
| 3DS | Azahar libretro 核心 | Vulkan + 自编 `malisx2` ICD；`azahar.sh` 启动 |
| GBA / GB / GBC | armGBA 核心 | 同时提供 gambatte/mgba 等基线核心 |
| PS2 | ARMSX2（`opt/armsx2-sdl`） | Vulkan + `malisx2`（`ps2.sh`） |
| GameCube / Wii | Dolphin NoGUI | Vulkan `VK_KHR_display` 直出 KMS（`dolphin.sh`） |
| PS1 | DuckStation 官方 mini AppImage | 每机型热键；设置/存档放 ROM 分区 |
| PSP | PPSSPP | 基线版本，保留多后端选择 |
| NDS | DSperate / DraStic | 需 BIOS，见下表 |
| Saturn | YabaSanshiro | 需 BIOS |
| 街机 | MAME / FBNeo 系列核心 | mame2015/2016 等为新增核心 |

**构建与 CI**

- `scripts/sync_image.sh`：源树 → 镜像同步；`--release` 生成发布镜像，
  `--ci` 原地清理（CI 用，不复制 12GB 镜像）
- `scripts/mount_arkos.sh`：按分区类型自动挂载镜像
- `.github/workflows/build-image.yml`：手动触发的云构建，自动下载基线镜像、
  构建、xz 压缩、超 1900MiB 自动 7z 分卷并上传 draft Release
- 仓库内 >100MB 的核心以 `.so.xz` 形式保存，CI 构建前自动解压；
  `sync_image.sh` 打包时排除 `*.so.xz`

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
/roms/gba|gb|gbc/ ...
```

### BIOS / 系统文件放哪里

统一放在 **`/roms/bios/`**（RetroArch 的 system 目录、DuckStation、ARMSX2
的 `[Folders] Bios` 都指向这里）：

| 平台 | 需要的文件 | 放置位置 |
|---|---|---|
| PS1（DuckStation / PCSX ReARMed） | `SCPH1001.BIN`（美版）、`SCPH5500`（日版）、`SCPH5501`（美版）、`SCPH5502`（欧版） | `/roms/bios/` |
| PS2（ARMSX2） | 任意有效 PS2 BIOS dump，如 `scph39001.bin`、`SCPH-70012_BIOS_V12_USA_200.bin` | `/roms/bios/` |
| NDS（DSperate） | `nds_bios9.bin`、`nds_bios7.bin`、`nds_firmware.bin` | `/roms/bios/` |
| Saturn（YabaSanshiro） | `sega_101.bin`（日版）、`mpr-17933.bin`（美/欧版） | `/roms/bios/` |
| Dreamcast（Flycast） | `dc_boot.bin`、`dc_flash.bin`（可选） | `/roms/bios/` |
| PCE CD / Sega CD 等光驱机种 | 对应核心要求的 BIOS | `/roms/bios/` |
| GBA（armGBA） | **不需要 BIOS** | — |
| 3DS（Azahar） | 游戏不需要 BIOS；部分游戏需要 3DS 系统文件，通过 Azahar 自身导入 | Azahar 自管 |
| N64 / SNES / MD 等卡带机种 | **不需要 BIOS** | — |

注意：

- `SCPH1001.BIN` 是 PS1 BIOS，**PS2 不能使用**
- PS2 没有 BIOS 时 ARMSX2 只能进主界面，无法启动游戏
- BIOS 文件名通常不强制，但大小/内容必须是正确 dump（模拟器按内容识别）

### 本地构建

```bash
# 依赖：sudo、losetup、rsync、btrfs-progs、exfatprogs、7z、xz、parted
# 把基线镜像放到仓库根目录，文件名必须是：
#   dArkOS_rg52mini_trixie_06242026.img

sudo ./scripts/sync_image.sh --release
```

产物：

```
dArkOS3562_work_MMDDYYYY.img
dArkOS3562_work_MMDDYYYY.img.sha256
```

首次开机说明：

- ROM 分区会被扩容并重新格式化为 exFAT，**刷机前请自行备份 ROM/BIOS/存档**
- 首次启动会执行 hook + 扩容并自动重启一次，第二次启动才进入 ES
- 镜像不保存 Wi-Fi 密码，进 ES 后重新连接

### 云端 CI

`.github/workflows/build-image.yml` 手动触发：

- 基线镜像默认从
  `bmdhacks/dArkOS_rg52mini` v06242026 的 `.7z.001/.002/.003` 下载
  （可用输入框或仓库变量 `DARKOS_BASE_URL` 覆盖）
- `publish=true`：创建 draft Release（tag `dArkOS-YYYYMMDD`）并上传产物
- `publish=false`：仅保存为 workflow artifact
- 产物为 `dArkOS3562_YYYYMMDD.img.xz`，超过 1900MiB 自动 7z 分卷

### 说明

- 内存/DDR 频率由 ATF 与 DDR 固件决定，本项目不再做内核覆盖
- 不包含 DuckStation 自编译版本，使用官方 AppImage
- 不提供任何商业 ROM/BIOS 文件

---

## English

### What this is

dArkOS for RK3562 is a **diff layer** on top of the read-only base image
`dArkOS_rg52mini_trixie_06242026.img`. Only files that we changed or added are
kept in this repository; `scripts/sync_image.sh` merges them into a working
image and produces a flashable full image.

- The base image is never modified and is not stored in the repo (~12GB)
- One image supports several RK3562 handhelds via U-Boot/DTB selection
- Target: Debian trixie (aarch64), Linux 5.10.226, Btrfs root, exFAT ROM partition

### Supported devices

| Device | DTB | Panel | Notes |
|---|---|---|---|
| NGP45HT | `rk3562-ngp45ht.dtb` | 1024x768 | main development/test unit |
| RG52 Mini | `rk3562-rg52mini.dtb` | 640x480 portrait | 90° rotated |
| RG43H Pro | `rk3562-rg43h.dtb` | 640x480 portrait | RG43V variant optional |
| RG43V Pro | `rk3562-rg43h.dtb` | 640x480 portrait | FN key + inverted left stick |
| XF55H | `rk3562-xf55h.dtb` | 640x480 portrait | ZT9101 USB Wi-Fi |
| Pocket AIS | `rk3562-ais.dtb` | — | SDIO Wi-Fi |

Select the device with the PC-side dtb selector (`dtbtools/`, `boot/dtbselector_*`)
or by editing `FDT` in `/boot/extlinux/extlinux.conf`. On first boot `hook.sh`
applies per-device quirks (SDL rotation libs, input mappings) and promotes
itself to `/boot/firstboot.sh` for subsequent boots.

### What is added on top of the base image

**Boot / kernel**

- AveyondFly RK3562 open U-Boot (`uboot/rk3562-uboot-16m.bin`, 16MB)
- Per-device DTB and extlinux configs; boot logo and charging animation
- Rebuilt kernel (Linaro 6.3.1 toolchain) including:
  - `rk3562-joystick` (`play_joystick`): mV dead zone, `axis_to_dpad`,
    `invert_abs*`, `swap_ab/swap_xy`, `swap_start_home`, `linear_triggers`,
    runtime calibration via `joypad_tuning`
  - stick RGB LED driver (`led-3562`), fan PWM, RK817 battery/poweroff fixes
  - Wi-Fi: AIC8800 (USB/SDIO), ZTop ZT9101 (USB), loaded per device
  - zram, Rockchip MPP hardware decoding for Kodi
- **No kernel DMC override**: available memory frequencies come from ATF
  (`DRAM_GET_FREQ_INFO`); the kernel follows the DT `system-status-level`.
  There is no `clamp_normal`-style parameter anymore.

**EmulationStation (fcamod)**

- Rebuilt and fully localized (Chinese/English)
- Joystick settings: dead zone (`adc_deadzone`, presets 32/64/128/256/384/512/768 mV,
  custom 10–1800, 0 = DT default), swap A/B, swap X/Y, linear trigger reporting,
  calibration
- Hardware menus: joystick LED, power LED, fan control, BATTERYPLUS, ZRAM,
  DMC max frequency
- Added systems: Nintendo 3DS, PlayStation 2, GameCube, Wii
- **PS Vita / Vita3K support removed**

**Emulators**

| Platform | Implementation | Notes |
|---|---|---|
| 3DS | Azahar libretro core | Vulkan + self-built `malisx2` ICD (`azahar.sh`) |
| GBA / GB / GBC | armGBA core | base gambatte/mgba cores still available |
| PS2 | ARMSX2 (`opt/armsx2-sdl`) | Vulkan + `malisx2` (`ps2.sh`) |
| GameCube / Wii | Dolphin NoGUI | Vulkan `VK_KHR_display` direct KMS (`dolphin.sh`) |
| PS1 | official DuckStation mini AppImage | per-device hotkeys, configs on ROM partition |
| PSP | PPSSPP | base build, multiple backends |
| NDS | DSperate / DraStic | BIOS required, see below |
| Saturn | YabaSanshiro | BIOS required |
| Arcade | MAME / FBNeo cores | mame2015/2016 cores are additions |

**Build & CI**

- `scripts/sync_image.sh`: source tree → image; `--release` for a release image,
  `--ci` for in-place cleanup (no 12GB copy)
- `scripts/mount_arkos.sh`: auto-mounts the image partitions
- `.github/workflows/build-image.yml`: manual cloud build; downloads the base
  image, builds, xz-compresses, splits into 7z volumes over 1900MiB and uploads
  to a draft Release
- Cores larger than GitHub's 100MB file limit are stored as `.so.xz` and
  decompressed by CI; `sync_image.sh` excludes `*.so.xz` from the image

### Repository layout

```
boot/      boot partition diff (kernel Image, hook.sh, DTBs, extlinux)
rootfs/    rootfs diff (/usr/local/bin, /opt, ES configs, ...)
uboot/     U-Boot 16MB blob and flasher
scripts/   sync_image.sh / mount_arkos.sh / CI helpers
dtbtools/  PC-side DTB selector
roms/      placeholder for the ROM tree (lives on the SD card)
.github/   CI workflows
```

### Where ROMs go

All ROMs live on the exFAT partition mounted at `/roms`:

```
/roms/3ds/     .3ds .cci .cxi .cia .3dsx .zip .7z
/roms/ps2/     .iso .chd .cso .bin .elf
/roms/gc/      .iso .gcm .rvz .wbfs
/roms/wii/     .iso .rvz .wbfs
/roms/psx/     .bin/.cue .chd .pbp
/roms/psp/     .iso .cso .chd .pbp
/roms/nds/     .nds .zip .7z
/roms/saturn/  .bin/.cue .chd
/roms/gba|gb|gbc/ ...
```

### Where BIOS / system files go

Everything goes to **`/roms/bios/`** (RetroArch system directory, DuckStation,
and ARMSX2 `[Folders] Bios` all point there):

| Platform | Files | Location |
|---|---|---|
| PS1 (DuckStation / PCSX ReARMed) | `SCPH1001.BIN` (US), `SCPH5500` (JP), `SCPH5501` (US), `SCPH5502` (EU) | `/roms/bios/` |
| PS2 (ARMSX2) | any valid PS2 BIOS dump, e.g. `scph39001.bin`, `SCPH-70012_BIOS_V12_USA_200.bin` | `/roms/bios/` |
| NDS (DSperate) | `nds_bios9.bin`, `nds_bios7.bin`, `nds_firmware.bin` | `/roms/bios/` |
| Saturn (YabaSanshiro) | `sega_101.bin` (JP), `mpr-17933.bin` (US/EU) | `/roms/bios/` |
| Dreamcast (Flycast) | `dc_boot.bin`, `dc_flash.bin` (optional) | `/roms/bios/` |
| PC Engine CD / Sega CD etc. | BIOS required by the specific core | `/roms/bios/` |
| GBA (armGBA) | **no BIOS required** | — |
| 3DS (Azahar) | games need no BIOS; some require 3DS system files imported via Azahar | managed by Azahar |
| N64 / SNES / Genesis etc. | **no BIOS required** | — |

Notes:

- `SCPH1001.BIN` is a **PS1** BIOS; it cannot be used for PS2
- Without a PS2 BIOS, ARMSX2 only reaches the main menu
- File names are usually not strict, but the content must be a valid dump

### Local build

```bash
# requirements: sudo, losetup, rsync, btrfs-progs, exfatprogs, 7z, xz, parted
# place the base image at the repository root with this exact name:
#   dArkOS_rg52mini_trixie_06242026.img

sudo ./scripts/sync_image.sh --release
```

Outputs:

```
dArkOS3562_work_MMDDYYYY.img
dArkOS3562_work_MMDDYYYY.img.sha256
```

First boot:

- the ROM partition is expanded and reformatted to exFAT — **back up ROMs,
  BIOS and saves before flashing**
- the first boot runs hook + expansion and reboots once; ES starts on the
  second boot
- Wi-Fi credentials are not stored in the image; reconnect from ES

### Cloud CI

`.github/workflows/build-image.yml` (manual trigger):

- by default the base image is downloaded from
  `bmdhacks/dArkOS_rg52mini` v06242026 (`.7z.001/.002/.003`); override with the
  `base_url` input or the `DARKOS_BASE_URL` repository variable
- `publish=true`: creates a draft Release (tag `dArkOS-YYYYMMDD`) and uploads
  the artifacts
- `publish=false`: keeps them as workflow artifacts
- output is `dArkOS3562_YYYYMMDD.img.xz`, split into 7z volumes when larger
  than 1900MiB

### Notes

- DDR/memory frequency is decided by ATF and the DDR firmware; this project no
  longer overrides it in the kernel
- DuckStation is the official AppImage, not a self-built copy
- No commercial ROMs or BIOS files are included
