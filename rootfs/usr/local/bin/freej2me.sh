#!/bin/bash

################################################################################################
# Created by Christian Haitian                                                                 #
# Includes some scripting from AmberELEC                                                       #
# https://github.com/AmberELEC/AmberELEC/blob/dev/packages/games/libretro/freej2me/freej2me.sh #
################################################################################################

directory="$(dirname "$3" | cut -d "/" -f2)"

if [ ! -f "/${directory}/bios/freej2me-lr.jar" ]; then
  cp -f /usr/local/bin/freej2me_files/freej2me-lr.jar /${directory}/bios/.
elif [[ $(cmp -s /usr/local/bin/freej2me_files/freej2me-lr.jar /${directory}/bios/freej2me-lr.jar) != 0 ]]; then
  cp -f /usr/local/bin/freej2me_files/freej2me-lr.jar /${directory}/bios/.
fi

if [ ! -f "/${directory}/bios/freej2me-plus-lr.jar" ]; then
  cp -f /usr/local/bin/freej2me_files/freej2me-plus-lr.jar /${directory}/bios/.
elif [[ $(cmp -s /usr/local/bin/freej2me_files/freej2me-plus-lr.jar /${directory}/bios/freej2me-plus-lr.jar) != 0 ]]; then
  cp -f /usr/local/bin/freej2me_files/freej2me-plus-lr.jar /${directory}/bios/.
fi

# 使用系统 JDK (dArkOS 自带 openjdk)
export PATH=/usr/bin:$PATH
if [ -n "$JAVA_HOME" ]; then unset JAVA_HOME; fi

if [[ ! -z "$(tr -d '\0' < /proc/device-tree/compatible | grep rk3326)" ]] && [[ $(tty) != *"pts"* ]]; then
  cp /home/ark/.asoundrcbak /home/ark/.asoundrc
fi

if [[ $1 == "freej2me-sa" ]]; then
  export SDL_GAMECONTROLLERCONFIG="1900a4dd726b333536322d6a6f797300,rk3562-joystick,a:b1,b:b0,x:b2,y:b3,back:b8,start:b9,guide:b10,misc1:b17,leftstick:b11,rightstick:b12,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftshoulder:b4,rightshoulder:b5,lefttrigger:a2,righttrigger:a5,leftx:a0,lefty:a1,rightx:a3,righty:a4,platform:Linux,"
  /opt/freej2mesa/run.sh "$3"
else
  if [ ! -d "/$directory/j2me/rms" ]; then
    mkdir -p /$directory/j2me/rms
  fi
  if [ ! -d "/dev/shm/j2me/rms" ]; then
    mkdir -p /dev/shm/j2me
  fi
  ln -sf /$directory/j2me/rms /dev/shm/j2me
  # 同样先复制成安全文件名, 避免空格/括号破坏 jar: URL
  SAFE="/tmp/freej2me-game.jar"
  cp -f "$3" "$SAFE"
  retroarch -L /home/ark/.config/retroarch/cores/${2}_libretro.so "$SAFE"
  rm -f "$SAFE"
fi
