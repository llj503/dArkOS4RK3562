#!/bin/bash

if [[ -e "/dev/input/by-path/platform-play_joystick-event-joystick" ]]; then
  # RK3562 (rk3562-joystick) -- SDL2 order, East=SDL-A (matches inttools/gamecontrollerdb.txt)
  sdl_controllerconfig="1900a4dd726b333536322d6a6f797300,rk3562-joystick,a:b1,b:b0,x:b2,y:b3,back:b8,start:b9,guide:b10,misc1:b17,leftstick:b11,rightstick:b12,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftshoulder:b4,rightshoulder:b5,lefttrigger:a2,righttrigger:a5,leftx:a0,lefty:a1,rightx:a3,righty:a4,platform:Linux,"
elif [[ -e "/dev/input/by-path/platform-ff300000.usb-usb-0:1.2:1.0-event-joystick" ]]; then
  sdl_controllerconfig="03000000091200000031000011010000,OpenSimHardware OSH PB Controller,a:b1,b:b0,x:b3,y:b2,leftshoulder:b4,rightshoulder:b5,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,leftx:a0~,lefty:a1~,leftstick:b8,lefttrigger:b10,rightstick:b9,back:b7,start:b6,rightx:a2,righty:a3,righttrigger:b11,platform:Linux,"
elif [[ -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
  if [[ ! -z $(cat /etc/emulationstation/es_input.cfg | grep "190000004b4800000010000001010000") ]]; then
    sdl_controllerconfig="190000004b4800000010000001010000,GO-Advance Gamepad (rev 1.1),a:b1,b:b0,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,dpdown:b9,dpleft:b10,dpright:b11,dpup:b8,leftx:a0,lefty:a1,back:b12,leftstick:b13,lefttrigger:b14,rightstick:b16,righttrigger:b15,start:b17,platform:Linux,"
  else
    sdl_controllerconfig="190000004b4800000010000000010000,GO-Advance Gamepad,a:b1,b:b0,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,dpdown:b7,dpleft:b8,dpright:b9,dpup:b6,leftx:a0,lefty:a1,back:b10,lefttrigger:b12,righttrigger:b13,start:b15,platform:Linux,"
  fi
elif [[ -e "/dev/input/by-path/platform-odroidgo3-joypad-event-joystick" ]]; then
  sdl_controllerconfig="190000004b4800000011000000010000,GO-Super Gamepad,x:b2,a:b1,b:b0,y:b3,back:b12,start:b13,dpleft:b10,dpdown:b9,dpright:b11,dpup:b8,leftshoulder:b4,lefttrigger:b6,rightshoulder:b5,righttrigger:b7,leftstick:b14,rightstick:b15,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Linux,"
elif [[ -e "/dev/input/by-path/platform-singleadc-joypad-event-joystick" ]]; then
  sdl_controllerconfig="190000004b4800000111000000010000,retrogame_joypad,a:b1,b:b0,x:b2,y:b3,back:b8,start:b9,rightstick:b12,leftstick:b11,dpleft:b15,dpdown:b14,dpright:b16,dpup:b13,leftshoulder:b4,lefttrigger:b6,rightshoulder:b5,righttrigger:b7,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Linux,"
else
  sdl_controllerconfig="19000000030000000300000002030000,gameforce_gamepad,leftstick:b14,rightx:a3,leftshoulder:b4,start:b9,lefty:a0,dpup:b10,righty:a2,a:b1,b:b0,guide:b16,dpdown:b11,rightshoulder:b5,righttrigger:b7,rightstick:b15,dpright:b13,x:b2,back:b8,leftx:a1,y:b3,dpleft:b12,lefttrigger:b6,platform:Linux,"
fi

if [ -f "/opt/system/Advanced/Switch to Main SD for Roms.sh" ]; then
  directory="roms2"
else
  directory="roms"
fi

# 配置放 roms 分区 (flycast 式软链)
CFG_DIR="/$directory/wolf/ecwolf"
mkdir -p "$CFG_DIR"
if [ -d "$HOME/.config/ecwolf" ] && [ ! -L "$HOME/.config/ecwolf" ]; then
  cp -a "$HOME/.config/ecwolf/." "$CFG_DIR/" 2>/dev/null
  rm -rf "$HOME/.config/ecwolf"
fi
ln -sfn "$CFG_DIR" "$HOME/.config/ecwolf"
[ -f "$CFG_DIR/ecwolf.cfg" ] || cp /opt/ecwolf/ecwolf.cfg.template "$CFG_DIR/ecwolf.cfg"

#if [[ ${2#*.} == "ecwolf" ]] || [[ ${2#*.} == "ECWOLF" ]]
if [[ $2 == *".ecwolf"* ]] || [[ $2 == *".ECWOLF"* ]]
then
  sudo dos2unix "${2}"
  while IFS== read -r key value; do
    if [ "$key" == "SUBDIR" ]; then
      gamedir="$value"
    fi
    if [ "$key" == "DATA" ]; then
      params+=" --data $value"
    fi
    if [ "$key" == "PK3" ]; then
      params+=" --file $value"
    fi
    if [ "$key" == "PK3_1" ]; then
      params+=" --file $value"
    fi
    if [ "$key" == "PK3_2" ]; then
      params+=" --file $value"
    fi
    if [ "$key" == "PK3_3" ]; then
      params+=" --file $value"
    fi
    if [ "$key" == "PK3_4" ]; then
      params+=" --file $value"
    fi
  done < "${2}"
  cd "/$directory/wolf/$gamedir"
  echo "VAR=ecwolf" > /home/ark/.config/KILLIT
  sudo systemctl restart killer_daemon.service
  SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig" /opt/ecwolf/ecwolf --savedir "/$directory/wolf/${gamedir}" ${params}
  sudo systemctl stop killer_daemon.service
  sudo systemctl restart ogage &
elif [[ $2 == "/$directory/wolf/Scan_for_new_games.wolf" ]]
then
  printf "\033c" >> /dev/tty1
  cd /$directory/wolf
  ./Scan_for_new_games.wolf
  printf "\n\nFinished scanning the wolf folder for games." >> /dev/tty1
  printf "\nPlease restart emulationstaton to find the new shortcuts" >> /dev/tty1
  printf "\ncreated if any.\n" >> /dev/tty1
  sleep 5
  printf "\033c" >> /dev/tty1
elif [[ $1 == "standalone" ]]
then
  filename="$(basename "$2")"
  cd "/$directory/wolf/${filename%.*}"
  echo "VAR=ecwolf" > /home/ark/.config/KILLIT
  sudo systemctl restart killer_daemon.service
  SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig" /opt/ecwolf/ecwolf --savedir "/$directory/wolf/${filename%.*}"
  sudo systemctl stop killer_daemon.service
  sudo systemctl restart ogage &
else
  filename="$(basename "$2")"
  game=$(find "/$directory/wolf/${filename%.*}" -type f -iname "*.exe" | grep -iv "install" | grep -iv "setup")
  /usr/local/bin/retroarch -L /home/ark/.config/retroarch/cores/ecwolf_libretro.so "$game"
fi

