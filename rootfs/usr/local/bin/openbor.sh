#!/bin/bash
# OpenBOR 引擎切换：openbor = 基线自带(/opt/OpenBor)，openborlns = AveyondFly LNS(/opt/openborlns)
case "$1" in
  openborlns)
    ROM="$2"
    [ -n "$ROM" ] || { echo "usage: $0 openborlns <game.pak>"; exit 2; }
    export SDL_GAMECONTROLLERCONFIG="1900a4dd726b333536322d6a6f797300,rk3562-joystick,a:b1,b:b0,x:b2,y:b3,back:b8,start:b9,guide:b10,misc1:b17,leftstick:b11,rightstick:b12,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftshoulder:b4,rightshoulder:b5,lefttrigger:a2,righttrigger:a5,leftx:a0,lefty:a1,rightx:a3,righty:a4,platform:Linux,"
    export SDL_GAMECONTROLLERCONFIG_FILE=/opt/inttools/gamecontrollerdb.txt
    echo "VAR=openbor" > /home/ark/.config/KILLIT
    sudo systemctl restart killer_daemon.service
    cd "$(dirname "$ROM")" 2>/dev/null || cd /opt/openborlns || exit 1
    /opt/openborlns/OpenBOR "$ROM"
    rc=$?
    sudo systemctl stop killer_daemon.service
    exit $rc
    ;;
  *)
    exec /opt/OpenBor/OpenBor.sh "$2"
    ;;
esac
