#!/bin/bash

. /usr/local/bin/buttonmon.sh

if compgen -G "/boot/rk3566*" > /dev/null; then
  if test ! -z "$(cat /home/ark/.config/.DEVICE | grep RGB20PRO | tr -d '\0')"
  then
    sudo setfont /usr/share/consolefonts/Lat7-TerminusBold32x16.psf.gz
  else
    sudo setfont /usr/share/consolefonts/Lat7-TerminusBold28x14.psf.gz
  fi
  height="20"
  width="60"
fi

printf "\nAre you sure you want to restore the joystick functionality for ECWolf standalone?\n"
printf "\nPress A to continue.  Press B to exit.\n"
while true
do
    Test_Button_A
    if [ "$?" -eq "10" ]; then
      sed -i "/JoystickEnabled \=/c\JoystickEnabled \= 1;" /home/ark/.config/ecwolf/ecwolf.cfg
      if [ $? == 0 ]; then
        printf "\nRestored the ECWolf standalone emulator joystick functionality."
        sleep 5
      else
        printf "\nFailed to restore the ECWolf standalone emulator joystick functionality."
        sleep 5
      fi
      exit 0
	fi

    Test_Button_B
    if [ "$?" -eq "10" ]; then
	  printf "\nExiting without restoring the ECWolf standalone emulator joystick functionality."
	  sleep 1
      exit 0
	fi
done
