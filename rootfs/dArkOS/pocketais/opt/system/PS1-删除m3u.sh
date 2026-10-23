#!/bin/bash
printf "\033c" >> /dev/tty1
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
sudo rm -f -v /roms/psx/*.m3u >> /dev/tty1
sudo rm -f -v /roms/psx/*.M3U >> /dev/tty1
sudo rm -f -v /roms/psx/*/*.m3u >> /dev/tty1
sudo rm -f -v /roms/psx/*/*.M3U >> /dev/tty1
printf "\nDone with deleting m3u files for for PS1.\nEmulationstation will now be restarted." >> /dev/tty1
sleep 3
printf "\033c" >> /dev/tty1
sudo systemctl restart emulationstation
