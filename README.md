# dArkOS 3562

[中文](#中文) | [English](#english)

---

## 中文

### 项目说明

dArkOS 3562 是面向 RK3562 掌机的**差异层**（diff layer）仓库：可刷写镜像由基线镜像
`dArkOS_rg52mini_trixie_06242026.img`（Debian trixie / aarch64、内核 5.10.226、
Btrfs rootfs、exFAT ROM 分区）叠加本仓库的 `boot/` 与 `rootfs/` 得到。基线镜像只读、
不进仓库；`scripts/sync_image.sh` 负责生成工作副本与发布镜像。

本文只描述**相对基线的改动与新增**。

### 致谢

本项目建立在上游工作之上，感谢：

- [christianhaitian/dArkOS](https://github.com/christianhaitian/dArkOS/)
- [bmdhacks/dArkOS_rg52mini](https://github.com/bmdhacks/dArkOS_rg52mini)

### 启动与镜像布局

- AveyondFly RK3562 开源 U-Boot（16MB blob，含开机 logo、关机充电、显示支持）
- 一镜像多机型：6 个 DTB（rg52mini / rg43h / rg43v / ais / ngp45ht / xf55h）+
  分机型 extlinux 配置；`console_detect` 按 DTB/运行时设备树识别机型；PC 端可用
  `dtbtools/` 的 dtbselector 选择（同时写 `/boot/.cn` 控制语言）
- **构建期分区定尺**（`scripts/repart_image.sh`）：
  boot 分区 256MiB、rootfs 11264MiB、ROM 分区占位到镜像尾部；出厂镜像首启只把 ROM
  分区重建为 exFAT 并扩到整卡末尾，rootfs 不再变动
- `/roms.tar` 由 `roms/` 增量 + 原厂骨架重新打包，首启解包（新增 3ds / krkr2 /
  psvita / wii 及各系统占位目录）
- `hook.sh` 分层：首启/换机型做全量 quirks（hostname、SDL 旋转库、ES/RA/PPSSPP
  输入、语言与工具菜单、ogage 热键、摇杆轴号、私编 DuckStation）；每次开机只做会被
  内核/设备重置的项（uinput 权限、WiFi 驱动、rk817 关机/音频、字体缓存、ldconfig）。
  背光/色温由 `brightness-watch` 开机恢复并常驻保存；DuckStation / ARMSX2 热键由
  各自启动器在启动时写入

### 内核

- 内核 5.10.226 重编（Linaro 6.3.1 交叉工具链）：
  - `rk3562-joystick`：mV 死区、`axis_to_dpad`、`invert_abs*`、`swap_ab/swap_xy`、
    `swap_start_home`、`linear_triggers`、`joypad_tuning` 运行时校准
  - 电源灯（`led-3562`）、风扇 PWM、RK817 电量与关机修复
  - Wi-Fi：AIC8800（SDIO/USB）、ZTop ZT9101（USB），按机型自动加载
  - zram、Kodi 的 Rockchip MPP 硬解
- DMC/内存频率不做内核覆盖：可用频点由 ATF/DDR 固件上报，内核按 DT 选择

### 独立模拟器（新增或更新）

| 平台 | 实现 | 说明 |
|---|---|---|
| PS2 | ARMSX2 | Vulkan + `malisx2 0.5.1`；BIOS 统一放 `/roms/bios`，按大小/内容自动识别 |
| GameCube / Wii | Dolphin NoGUI | Vulkan `VK_KHR_display` 直出 |
| PS1 | DuckStation 官方 mini AppImage | 每机型热键；设置/存档放 ROM 分区 |
| PSP | PPSSPP / PPSSPP 2021 | 2021 版启用 Vulkan（同时保留 GLES） |
| NDS | DSperate / DraStic | DSperate 走系统 Vulkan + 中文界面 |
| Saturn | YabaSanshiro | 4 个版本 |
| Dreamcast | Flycast 2.7 / Flycast 2022 | 均支持 Vulkan |
| PS Vita | Vita3K-Plus | 独立 Wayland 会话，运行库集中在 `/opt/vita3k` |
| J2ME | FreeJ2ME | 内置中文字体与手柄映射 |
| Flash | Ruffle | 新构建；按面板分辨率全屏，d-pad/摇杆为虚拟鼠标 |
| 视觉小说 | KRKR2 / onsCripter | KRKR2 游戏放 `/roms/krkr2` |
| Pico-8 | Fake08 | — |
| N64 | mupen64plus | GLideN64 / Rice 插件 |
| 冒险游戏 | ScummVM 2026.4.0 | 独立版，GIF/MPC、Vorbis、shader/vkeybd 齐全 |
| 横版引擎 | OpenBOR / OpenBOR LNS | 同一系统内切换 `openbor` / `openborlns` |
| 视频 | Kodi 21.3 | Rockchip MPP 硬解；关闭启动插件启用弹窗 |

### libretro 核心（新增或更新）

- **2026-11 批量更新**：snes9x2005、snes9x2010、snes9x2002、snes9x、bsnes、
  bsnes-jg、nestopia、fixNES、QuickNES、fceumm、Genesis-Plus-GX / Wide / Expanded、
  blastem、picodrive、smsplus-gx、Gearsystem —— 全部回到上游最新代码重编，64 位 +
  32 位，核心选项中文全部自行补全
- **Mesen CE**：新增核心，支持 NES / FDS / SNES / GB / GBC / GBA / PCE / SMS / GG /
  WonderSwan，核心选项中文，64 位 + 32 位
- armGBA v1.8：中文核心选项、GPIO 与 EZ-Flash 卡带震动，64 位 + 32 位
- armN64 v1.3（仅 64 位）；parallel_n64（GLES + Rice，另有 Vulkan 变体）
- PCE 家族（mednafen_pce_fast / pce / supergrafx）：中文选项、32 位版本、
  按 ROM 同名 `.BIOS` / `.bios` 自动加载
- 其它：Azahar（3DS，自编 malisx2 ICD）、ppsspp2021（Vulkan）、pcsx_rearmed（金手指）、
  GPSP（EZODE 震动）、mame2015/2016、native32、yabadabadoo、parallel_dc
- 32 位修复：picodrive 关闭可执行栈（`-Wl,-z,noexecstack`）；QuickNES 使用
  `NO_UNALIGNED_ACCESS` 避免 ARM 未对齐 `STRD` 崩溃

### EmulationStation

- 系统/核心列表随新增核心更新（blastem、fixnes、bsnes-jg、mesen2 及对应 32 位列表）
- 模拟器与核心在对应系统的 **SELECT** 菜单选择；OpenBOR 同系统内切换引擎
- 显示（亮度/伽马/色温）、摇杆（死区/校准/布局/扳机）、摇杆与电源灯、电池服务、
  风扇（Hotkey + Start）、性能（CPU/GPU/DMC 频率）、ZRAM、Wi-Fi/SSH、351Files

### 系统行为

- 关机充电不自动开机；充电时红色 LED + 震动提示，充满熄灭
- 电池读数调整（关闭 batteryplus 时用驱动数据）；长按音量键快速加减电量
- 亮度/色温持久化：`brightness-watch` 监控保存、开机恢复（游戏与 Kodi 同样生效）

### 构建

```bash
# 依赖：sudo、losetup、rsync、btrfs-progs、exfatprogs、parted、dosfstools、gdisk、7z、xz
# 基线镜像放仓库根目录，文件名固定：
#   dArkOS_rg52mini_trixie_06242026.img

sudo ./scripts/sync_image.sh --release
```

流程：刷 U-Boot → 构建期分区定尺 → 挂载 → 同步 boot/rootfs → 打包 roms.tar →
depmod → 清理首启状态 → 输出 `dArkOS3562_YYYYMMDD.img` 与 `.sha256`。
`DARKOS_BUILD_DATE=YYYYMMDD` 可复现日期；`--ci` 原地构建，不复制 12GB 镜像。

### 烧录与首次开机

- 用 dd / balenaEtcher 写入 SD 卡；**首启会重建 ROM 分区，刷机前备份 ROM/BIOS/存档**
- 首启：hook 应用机型 quirks → 重建 ROM 分区为 exFAT 并解包 roms.tar → 自动重启，
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

This document lists only the **changes and additions on top of the baseline**.

### Credits

Built on top of upstream work — thanks to:

- [christianhaitian/dArkOS](https://github.com/christianhaitian/dArkOS/)
- [bmdhacks/dArkOS_rg52mini](https://github.com/bmdhacks/dArkOS_rg52mini)

### Boot and image layout

- AveyondFly RK3562 open-source U-Boot (16 MB blob: boot logo, charging display,
  display support)
- One image for six models (rg52mini / rg43h / rg43v / ais / ngp45ht / xf55h) with
  per-model DTB and extlinux config; `console_detect` identifies the model,
  `dtbtools/` (PC) writes the selection (and `/boot/.cn` for language)
- **Build-time partitioning** (`scripts/repart_image.sh`): boot 256 MiB, rootfs
  11264 MiB, ROM partition placeholder at the image tail; first boot only rebuilds the ROM partition as exFAT and grows it to the card
  end — rootfs never changes on the device
- `/roms.tar` is repacked from `roms/` increments plus the vendor skeleton
  (adds 3ds / krkr2 / psvita / wii and per-system placeholders) and unpacked on first
  boot
- `hook.sh` is split in two: first boot / model change applies the full quirks
  (hostname, SDL rotation libs, ES/RA/PPSSPP input, language and tools menu, ogage
  hotkey, stick axes, private DuckStation); every boot only handles state that the
  kernel/devices reset (uinput, Wi-Fi modules, rk817 shutdown/audio, font cache,
  ldconfig). Backlight/color-temperature are restored by `brightness-watch`;
  DuckStation / ARMSX2 hotkeys are written by their launchers at start time

### Kernel

- Kernel 5.10.226 rebuilt with Linaro 6.3.1:
  - `rk3562-joystick`: mV deadzone, `axis_to_dpad`, `invert_abs*`, `swap_ab/swap_xy`,
    `swap_start_home`, `linear_triggers`, runtime `joypad_tuning`
  - power LED (`led-3562`), fan PWM, RK817 battery and shutdown fixes
  - Wi-Fi: AIC8800 (SDIO/USB), ZTop ZT9101 (USB), loaded automatically per model
  - zram, Rockchip MPP decoding for Kodi
- No kernel changes for DMC/memory frequency: points come from ATF/DDR firmware and
  the DT

### Standalone emulators (added or updated)

| Platform | Implementation | Notes |
|---|---|---|
| PS2 | ARMSX2 | Vulkan + `malisx2 0.5.1`; BIOS in `/roms/bios`, auto-detected by size/content |
| GameCube / Wii | Dolphin NoGUI | Vulkan via `VK_KHR_display` |
| PS1 | DuckStation official mini AppImage | per-model hotkeys; settings/saves on the ROM partition |
| PSP | PPSSPP / PPSSPP 2021 | the 2021 build enables Vulkan (GLES kept) |
| NDS | DSperate / DraStic | DSperate uses system Vulkan with a Chinese UI |
| Saturn | YabaSanshiro | four builds |
| Dreamcast | Flycast 2.7 / Flycast 2022 | both support Vulkan |
| PS Vita | Vita3K-Plus | dedicated Wayland session; runtime under `/opt/vita3k` |
| J2ME | FreeJ2ME | bundled CJK font and pad mapping |
| Flash | Ruffle | new build; fullscreen at panel resolution, d-pad/stick as virtual mouse |
| Visual novels | KRKR2 / onsCripter | KRKR2 games in `/roms/krkr2` |
| Pico-8 | Fake08 | — |
| N64 | mupen64plus | GLideN64 / Rice plugins |
| Adventure engine | ScummVM 2026.4.0 | standalone; GIF/MPC, Vorbis, shader/vkeybd bundled |
| Beat-em-up engine | OpenBOR / OpenBOR LNS | switch `openbor` / `openborlns` inside one system |
| Video | Kodi 21.3 | Rockchip MPP decoding; startup add-on prompts disabled |

### libretro cores (added or updated)

- **2026-11 update**: snes9x2005, snes9x2010, snes9x2002, snes9x, bsnes, bsnes-jg,
  nestopia, fixNES, QuickNES, fceumm, Genesis-Plus-GX / Wide / Expanded, blastem,
  picodrive, smsplus-gx, Gearsystem — all rebuilt from the latest upstream code, 64-bit
  and 32-bit, with Chinese core options written in-house
- **Mesen CE**: new core for NES / FDS / SNES / GB / GBC / GBA / PCE / SMS / GG /
  WonderSwan, Chinese options, 64-bit and 32-bit
- armGBA v1.8: Chinese options, GPIO and EZ-Flash rumble, 64-bit and 32-bit
- armN64 v1.3 (64-bit only); parallel_n64 (GLES + Rice, plus a Vulkan variant)
- PCE family (mednafen_pce_fast / pce / supergrafx): Chinese options, 32-bit builds,
  per-ROM `.BIOS` / `.bios` auto-load
- Others: Azahar (3DS, self-built malisx2 ICD), ppsspp2021 (Vulkan),
  pcsx_rearmed (cheats), GPSP (EZODE rumble), mame2015/2016, native32, yabadabadoo,
  parallel_dc
- 32-bit fixes: picodrive links with a non-executable stack; QuickNES builds with
  `NO_UNALIGNED_ACCESS` to avoid ARM unaligned `STRD` crashes

### EmulationStation

- System/core lists updated for the new cores (blastem, fixnes, bsnes-jg, mesen2 and
  their 32-bit entries)
- Emulator and core are chosen in each system's **SELECT** menu; OpenBOR switches
  engines within one system
- Display (brightness/gamma/color temperature), sticks (deadzone/calibration/layout/
  triggers), stick and power LEDs, battery service, fan (Hotkey + Start), performance
  (CPU/GPU/DMC clocks), ZRAM, Wi-Fi/SSH, 351Files

### System behaviour

- Charging while powered off does not boot; red LED plus a vibration when charging
  starts, LED off when full
- Battery readings tuned (driver data is used when batteryplus is off); long-press the
  volume keys to change the battery level quickly
- Brightness/color temperature persist: `brightness-watch` saves changes and restores
  them at boot (games and Kodi included)

### Build

```bash
# deps: sudo, losetup, rsync, btrfs-progs, exfatprogs, parted, dosfstools, gdisk, 7z, xz
# the baseline must be at the repository root:
#   dArkOS_rg52mini_trixie_06242026.img

sudo ./scripts/sync_image.sh --release
```

Pipeline: flash U-Boot → build-time partitioning → mount → sync boot/rootfs → pack
roms.tar → depmod → clear first-boot state → write `dArkOS3562_YYYYMMDD.img` and
`.sha256`. Use `DARKOS_BUILD_DATE=YYYYMMDD` to reproduce a date; `--ci` builds in
place without copying the 12 GB image.

### Flashing and first boot

- Write the image with dd or balenaEtcher; **the first boot rebuilds the ROM
  partition, so back up ROMs/BIOS/saves first**
- First boot: hook applies model quirks → ROM partition rebuilt as exFAT and roms.tar
  unpacked → automatic reboot; the second boot starts ES. Select the model and join
  Wi-Fi there (the image stores no Wi-Fi passwords)

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
