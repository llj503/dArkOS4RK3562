#!/bin/bash
# ============================================================
# dArkOS3562 GameCube/Wii 启动器 — Dolphin NoGUI
#   - Vulkan 后端 + malisx2 的 VK_KHR_display 直出 KMS (无需 compositor)
#   - 配置随 roms 分区: ~/.config/dolphin-emu -> /roms[d]2/dolphin-emu
#   - 存档/状态/截图/Wii NAND -> /roms[d]2/gc/ (同底包布局)
#   - SELECT+START 组合键退出 (PlatformFBDev 监听 evdev)
# 用法: dolphin.sh <rom>
# ============================================================
ROM="${1:-}"
APP=/opt/dolphin/dolphin-emu-nogui

# 屏幕旋转 (rg43v/rg52mini/xf55h: fbcon=rotate:1) -> KHR display 平面旋转
SCREEN_ROTATION=0
if [ -x /usr/local/bin/console_detect ]; then
  eval "$(/usr/local/bin/console_detect -s 2>/dev/null)" || true
fi
# 兜底: console_detect 不可用/返回 0 时, 读 fbcon 的 rotate 状态
# (/sys/class/graphics/fb0/rotate: 0=none 1=90 2=180 3=270)
if [ "${SCREEN_ROTATION:-0}" = "0" ] && [ -r /sys/class/graphics/fb0/rotate ]; then
  case "$(cat /sys/class/graphics/fb0/rotate 2>/dev/null)" in
    1) SCREEN_ROTATION=90 ;;
    2) SCREEN_ROTATION=180 ;;
    3) SCREEN_ROTATION=270 ;;
  esac
fi

export DOLPHIN_ROTATE="${SCREEN_ROTATION:-0}"

[ -x "$APP" ] || { echo "DOLPHIN: missing $APP"; sleep 5; exit 1; }

# ROM 所在分区 (roms / roms2), 与 dreamcast.sh 同一判定
directory=$(echo "$ROM" | cut -d "/" -f2)
[ -n "$directory" ] || directory="roms"
CFG_DIR="/$directory/dolphin-emu"
mkdir -p "$CFG_DIR"

# 配置目录放 roms 分区; 旧的实体目录先迁移再替换为软链
if [ -d "$HOME/.config/dolphin-emu" ] && [ ! -L "$HOME/.config/dolphin-emu" ]; then
  cp -a "$HOME/.config/dolphin-emu/." "$CFG_DIR/" 2>/dev/null
  rm -rf "$HOME/.config/dolphin-emu"
fi
ln -sfn "$CFG_DIR" "$HOME/.config/dolphin-emu"

# 存档/状态/截图/Wii NAND 指向 roms 分区
for d in GC StateSaves ScreenShots Wii; do
  if [ -d "$HOME/.local/share/dolphin-emu/$d" ] && [ ! -L "$HOME/.local/share/dolphin-emu/$d" ]; then
    rm -rf "$HOME/.local/share/dolphin-emu/$d"
  fi
  mkdir -p "/$directory/gc/$d"
  ln -sfn "/$directory/gc/$d" "$HOME/.local/share/dolphin-emu/$d"
done
mkdir -p "$HOME/.cache/dolphin-emu/Shaders"

# 首启配置模板
[ -f "$CFG_DIR/Dolphin.ini" ] || cp /opt/dolphin/Dolphin.ini.template "$CFG_DIR/Dolphin.ini"
[ -f "$CFG_DIR/GCPadNew.ini" ] || cp /opt/dolphin/GCPadNew.ini.template "$CFG_DIR/GCPadNew.ini"

# 手柄映射与 dreamcast.sh 一致 (这台机器的 A/B 索引)
export SDL_GAMECONTROLLERCONFIG="1900a4dd726b333536322d6a6f797300,rk3562-joystick,a:b1,b:b0,x:b2,y:b3,back:b8,start:b9,guide:b10,misc1:b17,leftstick:b11,rightstick:b12,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftshoulder:b4,rightshoulder:b5,lefttrigger:a2,righttrigger:a5,leftx:a0,lefty:a1,rightx:a3,righty:a4,platform:Linux,"
export SDL_AUDIODRIVER=alsa
export AUDIODEV=default
# malisx2 (glibc 版, 源码自编): PS2/Wii 必须用它, 系统 libmali 在这两个上会出问题
export VK_ICD_FILENAMES=/opt/malisx2/malisx2.json

# SELECT+START 退出 (killer_daemon 与 ps2.sh 一致; pkill 按进程名前缀匹配)
echo "VAR=dolphin-emu-nogui" > /home/ark/.config/KILLIT
sudo systemctl restart killer_daemon.service

nice -n 0 "$APP" -p drm -v Vulkan \
  -C Dolphin.DSP.Backend=ALSA \
  -C Graphics.Settings.ShowFPS=True \
  -C Graphics.Settings.ShowSpeed=True \
  -e "$ROM" > "$CFG_DIR/dolphin.log" 2>&1
RC=$?

sudo systemctl stop killer_daemon.service

# NoGUI 退出后把 ES 拉回来 (ES 启动模拟器时会退出)
if ! systemctl is-active --quiet emulationstation; then
  sudo systemctl start emulationstation
fi
exit $RC
