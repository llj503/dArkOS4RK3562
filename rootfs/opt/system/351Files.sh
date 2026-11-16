#!/bin/bash
export SDL_GAMECONTROLLERCONFIG="1900a4dd726b333536322d6a6f797300,rk3562-joystick,a:b1,b:b0,x:b2,y:b3,back:b8,start:b9,guide:b10,misc1:b17,leftstick:b11,rightstick:b12,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftshoulder:b4,rightshoulder:b5,lefttrigger:a2,righttrigger:a5,leftx:a0,lefty:a1,rightx:a3,righty:a4,platform:Linux,"
cd /opt/351Files
# 以 root 启动, 由程序弹出 root/普通模式选择; 普通模式内部降权
sudo SDL_GAMECONTROLLERCONFIG="$SDL_GAMECONTROLLERCONFIG" HOME="$HOME" ./351Files >351Files.log 2>&1
printf "\033c" >> /dev/tty1
