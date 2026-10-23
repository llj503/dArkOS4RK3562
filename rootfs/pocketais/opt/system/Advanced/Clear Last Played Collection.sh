#!/bin/bash

#clearlastplayed.sh
#Original script by Invisible89 (https://retropie.org.uk/forum/post/191868)
#Modified for use in Arkos by Christian Haitian

# Clear the screen
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

for f in /roms/*/gamelist.xml
do
echo "file: $f"
grep -e lastplayed -e playcount -v $f > "$f.tmp"
mv -f "$f.tmp" $f
done
for f in /roms2/*/gamelist.xml
do
echo "file: $f"
grep -e lastplayed -e playcount -v $f > "$f.tmp"
mv -f "$f.tmp" $f
done
for f in /opt/*/gamelist.xml
do
echo "file: $f"
grep -e lastplayed -e playcount -v $f > "$f.tmp"
mv -f "$f.tmp" $f
done
for f in /roms2/pico-8/*/gamelist.xml
do
echo "file: $f"
grep -e lastplayed -e playcount -v $f > "$f.tmp"
mv -f "$f.tmp" $f
done
for f in /roms/pico-8/*/gamelist.xml
do
echo "file: $f"
grep -e lastplayed -e playcount -v $f > "$f.tmp"
mv -f "$f.tmp" $f
done

printf "\n\n\nEmulationstation will now be restarted.\n\n" >> /dev/tty1
sleep 3
printf "\033c" >> /dev/tty1
sudo systemctl restart emulationstation
