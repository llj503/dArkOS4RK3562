#!/bin/bash
# ============================================================
# dArkOS3562 PS2 启动器 — ARMSX2 (pcsx2-sdl 掌机前端)
#
# G52 上 stock Mali blob 在 GS 初始化 abort (llj503 实测同样现象),
# 必须用 malisx2 0.4.0 的 Linux/kbase ICD (cortex-a53 编译,
# llj503/dArkOS-PokectAis release). 只在该次启动设 VK_ICD_FILENAMES,
# 不覆盖系统 rk_vk.json.
# 用法: ps2.sh <emulator> <rom>
# ============================================================
ROM="${2:-}"
DATA=/roms/ps2/armsx2
APP=/opt/armsx2-sdl/armsx2-sdl

[ -x "$APP" ] || { echo "PS2: missing $APP"; sleep 5; exit 1; }

mkdir -p "$DATA"/{inis,memcards,sstates,snaps,cache,textures,cheats,patches,resources,logs,inputprofiles,debuggerlayouts,debuggersettings} "$DATA/.config/ARMSX2/inis"

# 首启: 默认 ini (BIOS=/roms/bios, Vulkan, 全套路径指向 roms 分区).
# ARMSX2 的 DataRoot 是 .config/ARMSX2 (不是 PCSX2), ini 必须放这里.
if [ ! -f "$DATA/.config/ARMSX2/inis/PCSX2.ini" ]; then
  cp /opt/armsx2-sdl/PCSX2.ini.template "$DATA/.config/ARMSX2/inis/PCSX2.ini"
fi

# ARMSX2 退出时可能把 [Folders] Bios 写成相对 DataRoot 的 "bios"; 统一回 /roms/bios
sed -i 's|^Bios = .*|Bios = /roms/bios|' "$DATA/.config/ARMSX2/inis/PCSX2.ini"

export HOME="$DATA"
export XDG_CONFIG_HOME="$DATA/.config"
export XDG_DATA_HOME="$DATA/.local/share"
export SDL_GAMECONTROLLERCONFIG="1900a4dd726b333536322d6a6f797300,rk3562-joystick,a:b0,b:b1,x:b3,y:b2,back:b8,start:b9,guide:b10,misc1:b17,leftstick:b11,rightstick:b12,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftshoulder:b4,rightshoulder:b5,lefttrigger:a2,righttrigger:a5,leftx:a0,lefty:a1,rightx:a3,righty:a4,platform:Linux,"
export SDL_AUDIODRIVER=alsa
export AUDIODEV=default

# 跟随 ES 语言 (与 flycast/yabasanshiro 同一套判定): ES 选中文时导出 zh_CN.UTF-8,
# ARMSX2 按 locale 加载 resources/translations/zh-CN.tsv, 否则保持英文。
if grep -q '<string name="Language" value="zh-CN" />' /home/ark/.emulationstation/es_settings.cfg 2>/dev/null; then
  export LANG=zh_CN.UTF-8
  export LC_ALL=zh_CN.UTF-8
else
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
fi

# G52 必须 malisx2 (llj503 实测: stock blob GS 初始化 abort)
unset VK_ICD_FILENAMES
export VK_ICD_FILENAMES=/opt/malisx2/malisx2.json

# 日志留档 (再闪退直接发 /roms/ps2/armsx2/logs/last_run.log)
LOG="$DATA/logs/last_run.log"
# SELECT+START 退出 (killer_daemon 与其它 standalone 一致)
echo "VAR=armsx2" > /home/ark/.config/KILLIT
sudo systemctl restart killer_daemon.service
nice -n -19 "$APP" --fullscreen-mode 1024x768 ${ROM:+"$ROM"} > "$LOG" 2>&1
RC=$?
sudo systemctl stop killer_daemon.service

# 退出后若 ES 没在跑（手动/Ports 启动且事先停了 ES）就拉回 ES，避免落在 tty1
# 控制台；从 ES 菜单启动时 ES 本就 active，不会重复启动。
if ! systemctl is-active --quiet emulationstation; then
  sudo systemctl start emulationstation
fi

sync
exit $RC
