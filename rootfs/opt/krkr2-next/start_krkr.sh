#!/bin/bash
# KrKr2 Next — KiriKiri2 (TJS/KAG) 引擎, SDL2 + OpenGL ES (KMSDRM)
# 用法: start_krkr.sh <game.xp3>
. /etc/profile 2>/dev/null

ROM="${1:-}"
[ -n "$ROM" ] || { echo "usage: $0 <game.xp3>"; exit 2; }

APP=/opt/krkr2-next
CFG=/home/ark/.config/krkr2

mkdir -p "$CFG" 2>/dev/null
chmod -R 777 "$CFG" 2>/dev/null

[ -f "$CFG/krkr2.gptk" ] || cp -f "$APP/krkr2.gptk" "$CFG/" 2>/dev/null

# 默认字体 (CJK): 游戏脚本缺省字体时使用
if [ ! -f "$CFG/default.ttf" ]; then
  for cand in /usr/bin/emulationstation/resources/DroidSansFallbackFull.ttf \
              /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf; do
    [ -f "$cand" ] && { cp -f "$cand" "$CFG/default.ttf"; break; }
  done
fi

export LD_LIBRARY_PATH="$APP/lib:${LD_LIBRARY_PATH:-}"
export SDL_VIDEODRIVER=kmsdrm
export SDL_VIDEO_EGL_DRIVER=libEGL.so
export SDL_AUDIODRIVER=alsa
export AUDIODEV=default
[ -f /home/ark/.config/.cn ] && export LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8

chmod 666 /dev/uinput 2>/dev/null || true
echo "VAR=krkr2" > /home/ark/.config/KILLIT 2>/dev/null
sudo systemctl restart killer_daemon.service 2>/dev/null

# 手柄映射: 引擎内置 (左摇杆/十字键=光标, A=左键+Enter, B=右键+Esc, X=空格)
export SDL_GAMECONTROLLERCONFIG="1900a4dd726b333536322d6a6f797300,rk3562-joystick,a:b0,b:b1,x:b3,y:b2,back:b8,start:b9,guide:b10,misc1:b17,leftstick:b11,rightstick:b12,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftshoulder:b4,rightshoulder:b5,lefttrigger:a2,righttrigger:a5,leftx:a0,lefty:a1,rightx:a3,righty:a4,platform:Linux,"
export SDL_GAMECONTROLLERCONFIG_FILE=/opt/inttools/gamecontrollerdb.txt

GP=""

cd "$CFG" || exit 1
"$APP/krkr2" "$ROM" 2>&1 | tee -a "$CFG/log.txt"
rc=${PIPESTATUS[0]}

sudo systemctl stop killer_daemon.service 2>/dev/null

if ! systemctl is-active --quiet emulationstation; then
  sudo systemctl start emulationstation
fi
exit "$rc"
