#!/bin/bash
directory="$(dirname "$1" | cut -d "/" -f2)"
# The DSperate standalone emulator does not support 7z archive files.  We'll take care of that here
game="$1"
ext="${1##*.}"
if [[ "${ext,,}" == "7z" ]]; then
    if [ ! -d "/dev/shm/ndsroms" ]; then
        mkdir -p /dev/shm/ndsroms
    else
        rm -rf /dev/shm/ndsroms/*
    fi
    # game variable will be updated with the file that is found in the 7z archive
    ROM="$game"
    7z e "$ROM" -bd -aoa -o/dev/shm/ndsroms/

    if [ $? != 0 ]; then
        printf "\nCouldn't decompress $ROM\nSomething seems to be wrong with this archive." > /dev/tty1
        sleep 5
        printf "\033c" > /dev/tty1
        exit 1
    fi

    for CART in nds NDS; do
        game=`find /dev/shm/ndsroms/ -iname "*.${CART}" | tac | head -n 1`
        if [ ! -z "$game" ]; then
        break;
        fi
    done
    if [ -z "$game" ]; then
        printf "\nCouldn't find a compatible rom of type .nds or .NDS in $ROM\n" > /dev/tty1
        sleep 5
        printf "\033c" > /dev/tty1
        exit 1
    fi
fi

if [[ ! -d "/${directory}/nds/dsperate" ]]; then
    mkdir /${directory}/nds/dsperate
    cp /opt/DSperate/config/dsperate.ini /${directory}/nds/dsperate/.
fi

if [[ ! -s "/${directory}/nds/dsperate/dsperate.ini" ]]; then
    cp /opt/DSperate/config/dsperate.ini /${directory}/nds/dsperate/.
fi

if [[ -d /home/ark/.config/dsperate && ! -L /home/ark/.config/dsperate ]]; then
    rm -rf /home/ark/.config/dsperate
fi

ln -sfn /${directory}/nds/dsperate /home/ark/.config/

if grep -q '<string name="Language" value="zh-CN" />' /home/ark/.emulationstation/es_settings.cfg; then
    export LANG=zh_CN.UTF-8
    target="/opt/DSperate/zh.dat"
else
    target="/opt/DSperate/en.dat"
fi

if [ -L /opt/DSperate/usrcheat.dat ]; then
    if [ "$(readlink /opt/DSperate/usrcheat.dat)" != "$target" ]; then
        sudo rm -f /opt/DSperate/usrcheat.dat
        sudo ln -sf "$target" /opt/DSperate/usrcheat.dat
    fi
else
    sudo ln -sf "$target" /opt/DSperate/usrcheat.dat
fi

if [[ ! -d "/${directory}/nds/savestates" ]]; then
    mkdir /${directory}/nds/savestates
fi

sed -i "/saves =/c\saves = /${directory}/nds" /${directory}/nds/dsperate/dsperate.ini
sed -i "/states =/c\states = /${directory}/nds/savestates" /${directory}/nds/dsperate/dsperate.ini
sed -i "/cheats =/c\cheats = /opt/DSperate/usrcheat.dat" /${directory}/nds/dsperate/dsperate.ini

# Vulkan 走系统默认 ICD (新版 libmali 自带 ARM Vulkan + KHR_display);
# 3D 栅格可用菜单 video.gpu3d 打开, DS_GPU3D_API=gles 可换 OpenGL ES

sdl_controllerconfig="1900a4dd726b333536322d6a6f797300,rk3562-joystick,a:b0,b:b1,x:b2,y:b3,back:b8,guide:b10,start:b9,leftstick:b11,rightstick:b12,leftshoulder:b4,rightshoulder:b5,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftx:a0,lefty:a1,rightx:a3,righty:a4,lefttrigger:a2,righttrigger:a5,platform:Linux,"
echo "VAR=dsperate" > /home/ark/.config/KILLIT
sudo systemctl restart killer_daemon.service
if grep -q '<string name="Language" value="zh-CN" />' /home/ark/.emulationstation/es_settings.cfg; then
    SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig" LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 /opt/DSperate/dsperate "$game" --bios9 /${directory}/bios/nds_bios9.bin --bios7 /${directory}/bios/nds_bios7.bin --firmware /${directory}/bios/nds_firmware.bin
else
    SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig" /opt/DSperate/dsperate "$game" --bios9 /${directory}/bios/nds_bios9.bin --bios7 /${directory}/bios/nds_bios7.bin --firmware /${directory}/bios/nds_firmware.bin
fi
sudo systemctl stop killer_daemon.service
if [ -d "/dev/shm/ndsroms" ]; then
rm -rf /dev/shm/ndsroms
fi