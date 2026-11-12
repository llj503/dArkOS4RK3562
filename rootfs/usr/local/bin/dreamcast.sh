#!/bin/bash

sudo chmod 666 /dev/tty1
ESUDO=""

if [[ $1 == "retroarch" ]]; then
	/usr/local/bin/"$1" -L /home/ark/.config/"$1"/cores/"$2"_libretro.so "$3"
elif [[ $1 == "retroarch32" ]]; then
	/usr/local/bin/"$1" -L /home/ark/.config/"$1"/cores/"$2"_libretro.so "$3"
elif [[ $1 == *"standalone"* ]]; then
	echo "VAR=flycast" >/home/ark/.config/KILLIT
	sudo systemctl restart killer_daemon.service
	rm -rf "/home/ark/.local/share/flycast"
	directory=$(dirname "$2" | cut -d "/" -f2)
  [ -d "/$directory/bios/dc" ] || mkdir -p "/$directory/bios/dc"
	ln -sf "/$directory/bios/dc" "/home/ark/.local/share/flycast"
  # 配置放 roms 分区 (flycast 式软链)
  mkdir -p "/$directory/dreamcast/flycast"
  if [ -d "$HOME/.config/flycast" ] && [ ! -L "$HOME/.config/flycast" ]; then
    cp -a "$HOME/.config/flycast/." "/$directory/dreamcast/flycast/" 2>/dev/null
    rm -rf "$HOME/.config/flycast"
  fi
  ln -sfn "/$directory/dreamcast/flycast" "$HOME/.config/flycast"
  [ -f "/$directory/dreamcast/flycast/emu.cfg" ] || cp /opt/flycastsa/emu.cfg.template "/$directory/dreamcast/flycast/emu.cfg"
  sdl_controllerconfig="1900a4dd726b333536322d6a6f797300,rk3562-joystick,a:b1,b:b0,x:b2,y:b3,back:b8,start:b9,guide:b10,misc1:b17,leftstick:b11,rightstick:b12,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftshoulder:b4,rightshoulder:b5,lefttrigger:a2,righttrigger:a5,leftx:a0,lefty:a1,rightx:a3,righty:a4,platform:Linux,"
  if [[ $1 == *"-2022"* ]]; then
      FLYCAST_BIN="/opt/flycastsa/flycast-2022"
  else
      FLYCAST_BIN="/opt/flycastsa/flycast"
  fi
  if grep -q '<string name="Language" value="zh-CN" />' /home/ark/.emulationstation/es_settings.cfg; then
      SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig" LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 $FLYCAST_BIN "$2"
  else
      SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig" $FLYCAST_BIN "$2"
  fi
	sudo systemctl stop killer_daemon.service
	sudo systemctl restart ogage &
elif [[ $1 == "retrorun"* ]]; then
	directory=$(dirname "$3" | cut -d "/" -f2)
	CURDIRECTORYSET="$(grep "retrorun_screenshot_folder = " /home/ark/.config/retrorun.cfg | cut -d "/" -f2-3)"
	if [[ "${CURDIRECTORYSET}" != "${directory}/dreamcast" ]]; then
		sed -i "/retrorun_screenshot_folder \=/c\retrorun_screenshot_folder \= \/$directory\/dreamcast" /home/ark/.config/retrorun.cfg
	fi
 if [[ $1 == "retrorun" ]]; then
    RETRORUN_BIN="/opt/retrorun/retrorun"
    CORE=""
  elif [[ $1 == "retrorun32" ]]; then
    RETRORUN_BIN="/opt/retrorun/retrorun32"
    CORE="32"
    # 旧 quirks/retrorun32_libs 是 bionic 时代库(旧 libssh2 无 1.11 符号), 系统
    # 32 位链已补齐, 注入只会引发 symbol lookup error — 不再使用
  fi
  export GLIBC_TUNABLES=glibc.rtld.execstack=2
  DEVICENAME="RG351P" $ESUDO $RETRORUN_BIN -c /home/ark/.config/retrorun.cfg --triggers -s /$directory/dreamcast -d /$directory/bios /home/ark/.config/retroarch$CORE/cores/"$2"_libretro.so "$3"
  printf "\033c" >> /dev/tty1
else
  DEVICENAME="RG351P"
	directory=$(dirname "$3" | cut -d "/" -f2)
	CURDIRECTORYSET="$(grep "retrorun_screenshot_folder = " /home/ark/.config/retrorun.cfg | cut -d "/" -f2-3)"
	if [[ "${CURDIRECTORYSET}" != "${directory}/dreamcast" ]]; then
		sed -i "/retrorun_screenshot_folder \=/c\retrorun_screenshot_folder \= \/$directory\/dreamcast" /home/ark/.config/retrorun.cfg
	fi
	$ESUDO /usr/local/bin/retrorun32 -c /home/ark/.config/retrorun.cfg --triggers -s /$directory/dreamcast -d /$directory/bios /home/ark/.config/retroarch32/cores/"$2"_libretro.so "$3"
	printf "\033c" >>/dev/tty1
fi
