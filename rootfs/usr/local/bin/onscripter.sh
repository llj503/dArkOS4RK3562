#!/bin/bash


romfile=${1}
filename=$(basename "$romfile")
romdir=${romfile%/*}

ESUDO="sudo"
ESUDOKILL="-sudokill" 
if [ -f "/storage/.config/.OS_ARCH" ]; then
ESUDO=""
ESUDOKILL="-1" # -1 (numeric one) or "-k" for EmuELEC
fi

if [ $filename == "Scan_for_new_games.ons" ]; then
    "$romfile"
else
    prodir="/opt/onscripter"
    $ESUDO chmod 666 /dev/uinput
    cd $prodir
    rm -f ./log.txt
    SDL_GAMECONTROLLERCONFIG_FILE="./gamecontrollerdb.txt" ./gptokeyb $ESUDOKILL "onscripter" -c "./onscripter.gptk" &
    echo "VAR=onscripter" > /home/ark/.config/KILLIT
    sudo systemctl restart killer_daemon.service
    ./onscripter -r "$romdir" 2>&1 | tee -a ./log.txt
    sudo systemctl stop killer_daemon.service
    kill -9 $(pidof gptokeyb) 2>/dev/null
    printf "\033c" >> /dev/tty1
fi
