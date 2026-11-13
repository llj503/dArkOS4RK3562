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

# BIOS 目录: 共享 /roms/bios 里通常只有 PS1 BIOS (512K, ARMSX2 会报
# BIOSNotUsable), PS2 BIOS 在各机型的 /roms/ps2/bios (4M)。优先用后者。
BIOS_DIR=/roms/bios
for f in /roms/ps2/bios/*.BIN /roms/ps2/bios/*.bin; do
  [ -f "$f" ] && [ "$(stat -c %s "$f" 2>/dev/null)" = 4194304 ] && BIOS_DIR=/roms/ps2/bios && break
done
sed -i "s|^Bios = .*|Bios = $BIOS_DIR|" "$DATA/.config/ARMSX2/inis/PCSX2.ini"

# ARMSX2 异常退出时会把 ini 写回默认 (Renderer=-1 会直接黑屏退出, Bios 会变回
# 相对路径 "bios"), 每次启动都强制修正这两个关键项
sed -i -E 's|^Renderer = .*|Renderer = 14|' "$DATA/.config/ARMSX2/inis/PCSX2.ini"

# 打开暂停菜单 = 机型热键 + X (与 hook.sh 同一套映射: mode=Guide, select=Back,
# 其余=Misc1). ARMSX2 退出时会重写 ini 把 [Hotkeys] 还原成 Keyboard/Escape,
# 光在 hook 里写会被冲掉, 所以每次启动前都重新写一遍.
HOTKEY_TYPE=happy5
[ -x /usr/local/bin/console_detect ] && eval "$(/usr/local/bin/console_detect -s 2>/dev/null)" || true
case "${HOTKEY_TYPE:-happy5}" in
  select) HK="SDL-0/Back"  ;;
  mode)   HK="SDL-0/Guide" ;;
  *)      HK="SDL-0/Misc1" ;;
esac
INI="$DATA/.config/ARMSX2/inis/PCSX2.ini"
sed -i -E '/^OpenPauseMenu[[:space:]]*=/d' "$INI" 2>/dev/null || true
if grep -q '^\[Hotkeys\]' "$INI" 2>/dev/null; then
  awk -v l="OpenPauseMenu = $HK & SDL-0/FaceWest" '{ print } /^\[Hotkeys\]/{ print l }' "$INI" > "$INI.tmp" \
    && mv "$INI.tmp" "$INI"
else
  printf '\n[Hotkeys]\nOpenPauseMenu = %s & SDL-0/FaceWest\n' "$HK" >> "$INI"
fi

# ARMSX2 解析极简单轨 .cue 会失败 (DoCDVDopen), 但直接读同一 .bin 正常;
# 单轨 cue 自动换成它引用的 bin。
case "${ROM##*.}" in
  cue|CUE)
    _bn=$(sed -n 's/^FILE "\(.*\)" BINARY.*/\1/p' "$ROM" 2>/dev/null | head -1)
    if [ -n "$_bn" ] && [ "$(grep -c '^[[:space:]]*TRACK' "$ROM" 2>/dev/null)" = "1" ] \
       && [ -f "$(dirname "$ROM")/$_bn" ]; then
      ROM="$(dirname "$ROM")/$_bn"
    fi
    ;;
esac

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
