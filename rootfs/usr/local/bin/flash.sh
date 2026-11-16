#!/bin/bash

cd /opt/rufflesa

# 手柄配置
sdl_controllerconfig="1900a4dd726b333536322d6a6f797300,rk3562-joystick,a:b0,b:b1,x:b2,y:b3,back:b8,guide:b10,start:b9,leftstick:b11,rightstick:b12,leftshoulder:b4,rightshoulder:b5,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftx:a0,lefty:a1,rightx:a3,righty:a4,lefttrigger:a2,righttrigger:a5,platform:Linux,"

echo "VAR=rufflesa" > /home/ark/.config/KILLIT
sudo systemctl restart killer_daemon.service
SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig" ./rufflesa "$1" -Q low
RC=$?
sudo systemctl stop killer_daemon.service
exit $RC
