#!/bin/bash
#
# LED Settings -- configure the analog-stick RGB lighting on AISLPC RK3562
# handhelds (RG52 Mini / RG43H Pro / RG43V Pro).
#
# A small dialog front-end (modelled on Wifi.sh) over /usr/local/bin/ledctl,
# which talks to the on-board LED MCU on /dev/ttyS1. The lighting is OFF by
# default; everything here is opt-in and persisted to ~/.config/led.cfg.
#

CFG=/home/ark/.config/led.cfg
LEDCTL=/usr/local/bin/ledctl

sudo chmod 666 /dev/tty1
reset
printf "\e[?25l" > /dev/tty1          # hide cursor
dialog --clear

height=15
width=55

export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

sudo setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz 2>/dev/null

# --- gamepad -> keyboard for dialog navigation (same as Wifi.sh) ----------
sudo chmod 666 /dev/uinput
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
pgrep -f gptokeyb | sudo xargs -r kill -9
pgrep -f osk.py   | sudo xargs -r kill -9
/opt/inttools/gptokeyb -1 "LED设置.sh" -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &

printf "\033c" > /dev/tty1

# Effect catalogue: "label|mode-byte" (chgmode value understood by the MCU).
EFFECTS=(
  "Red|3"            "Green|1"            "Blue|2"
  "Yellow|5"         "Cyan|4"             "Magenta|6"
  "Rainbow|7"        "Scrolling|8"
  "Breathing Red|19" "Breathing Green|17" "Breathing Blue|18"
  "Breathing Rainbow|23" "Breathing Cycle|24"
)

read_cfg() {
  ENABLED=0; MODE=3; BRI=5
  # shellcheck source=/dev/null
  [ -f "$CFG" ] && . "$CFG"
}

effect_name() {   # $1 = mode byte -> label
  local e
  for e in "${EFFECTS[@]}"; do
    [ "${e##*|}" = "$1" ] && { echo "${e%%|*}"; return; }
  done
  echo "Custom ($1)"
}

ExitMenu() {
  printf "\033c" > /dev/tty1
  pgrep -f gptokeyb | sudo xargs -r kill -9
  sudo setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz 2>/dev/null
  exit 0
}

ChooseEffect() {
  local opts=() e
  for e in "${EFFECTS[@]}"; do
    opts+=("${e##*|}" "${e%%|*}")
  done
  local choice
  choice=$(dialog --clear --no-collapse --cancel-label "Back" \
    --menu "Pick a colour / effect" $height $width 10 \
    "${opts[@]}" 2>&1 > /dev/tty1) || return
  [ -n "$choice" ] && sudo "$LEDCTL" mode "$choice"
}

ChooseBrightness() {
  local choice
  choice=$(dialog --clear --no-collapse --cancel-label "Back" \
    --menu "Brightness (1 = dim, 9 = bright)" $height $width 9 \
    9 "9 - brightest" 8 "8" 7 "7" 6 "6" 5 "5" \
    4 "4" 3 "3" 2 "2" 1 "1 - dimmest" 2>&1 > /dev/tty1) || return
  [ -n "$choice" ] && sudo "$LEDCTL" bri "$choice"
}

MainMenu() {
  while true; do
    read_cfg
    local stat toggle
    if [ "$ENABLED" = "1" ]; then stat="On"; toggle="Turn lighting Off"
    else stat="Off"; toggle="Turn lighting On"; fi

    local choice
    choice=$(dialog \
      --backtitle "Stick Lighting: $stat  |  Effect: $(effect_name "$MODE")  |  Brightness: $BRI" \
      --title "LED Settings" \
      --no-collapse --clear --cancel-label "Exit" \
      --menu "" $height $width 10 \
      1 "$toggle" \
      2 "Colour / Effect" \
      3 "Brightness" \
      4 "Exit" \
      2>&1 > /dev/tty1) || ExitMenu

    case $choice in
      1) if [ "$ENABLED" = "1" ]; then sudo "$LEDCTL" off; else sudo "$LEDCTL" on; fi ;;
      2) ChooseEffect ;;
      3) ChooseBrightness ;;
      4) ExitMenu ;;
      *) ExitMenu ;;
    esac
  done
}

trap ExitMenu EXIT
MainMenu
