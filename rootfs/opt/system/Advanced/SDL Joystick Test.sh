#!/bin/bash
# SDL Joystick Test (sdljoytest, from christianhaitian/sdljoytest)
# Select+Start (hotkey combination, gptokeyb) exits.
printf "\033c" > /dev/tty1
sudo chmod 666 /dev/tty1 /dev/uinput 2>/dev/null

export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"

started=
if [[ -z $(pgrep -f gptokeyb) ]]; then
	/opt/inttools/gptokeyb -1 "sdljoytest" -c "/opt/inttools/keys.gptk" >/dev/null &
	disown
	started=Y
fi

echo "Joystick test — move sticks, press buttons."
echo "Press Select+Start to exit."

SDL_VIDEODRIVER=kmsdrm /usr/local/bin/sdljoytest

if [[ -n "$started" ]]; then
	pgrep -f gptokeyb | sudo xargs -r kill -9
fi
printf "\033c" > /dev/tty1
