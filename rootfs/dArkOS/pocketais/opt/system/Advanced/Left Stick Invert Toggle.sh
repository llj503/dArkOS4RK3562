#!/bin/bash
printf "\033c" >> /dev/tty1
current=$(cat /sys/devices/platform/play_joystick/left_stick_invert)
if [ "$current" = "1" ]; then
  new=0
  touch /home/ark/.config/.LEFT_STICK_NOT_INVERTED
  msg="Left stick inversion disabled."
else
  new=1
  rm -f /home/ark/.config/.LEFT_STICK_NOT_INVERTED
  msg="Left stick inversion enabled."
fi
echo $new | sudo tee /sys/devices/platform/play_joystick/left_stick_invert > /dev/null
printf "\n\n\n\e[32m%s\n" "$msg" > /dev/tty1
sleep 2
printf "\033c" >> /dev/tty1
sudo systemctl restart emulationstation
