#!/bin/bash
# usage: flash.sh [rufflesa] <game.swf>
ROM="$2"
[ -n "$ROM" ] || ROM="$1"
[ -f "$ROM" ] || { echo "usage: $0 rufflesa <game.swf>"; exit 2; }

cd /opt/rufflesa || exit 1

# 面板分辨率（与 n64.sh 同一来源）；viewport 给整屏，Ruffle letterbox 等比缩放
read xres yres <<EOF
$(console_detect -r 2>/dev/null | tr 'x' ' ')
EOF
[ -n "$xres" ] && [ -n "$yres" ] || { xres=1024; yres=768; }

# 手柄配置
sdl_controllerconfig="1900a4dd726b333536322d6a6f797300,rk3562-joystick,a:b0,b:b1,x:b2,y:b3,back:b8,guide:b10,start:b9,leftstick:b11,rightstick:b12,leftshoulder:b4,rightshoulder:b5,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftx:a0,lefty:a1,rightx:a3,righty:a4,lefttrigger:a2,righttrigger:a5,platform:Linux,"

echo "VAR=rufflesa" > /home/ark/.config/KILLIT
sudo systemctl restart killer_daemon.service
SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig" ./rufflesa "$ROM" -W "$xres" -H "$yres" -Q low
RC=$?
sudo systemctl stop killer_daemon.service
exit $RC
