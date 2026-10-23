#!/bin/bash

##################################################################
# Created by Christian Haitian for use to set performance        #
# governors to powersave before sleep then restore previously    #
# set governors on wake primarily for rk3566 devices.            #
# This should work fine on rk3326 devices as well.               #
# See the LICENSE.md file at the top-level directory of this     #
# repository.                                                    #
##################################################################

if [[ "$(tr -d '\0' < /proc/device-tree/compatible)" == *"rk3326"* ]]; then
  gpu="ff400000"
else
  gpu="ff320000"
fi

function SaveSettingsOnSleep() {
   if [ -f "/var/local/governor_settings.state" ]; then
     sudo rm -f /var/local/governor_settings.state
   fi
   if [ -f "/var/local/userspace_speed_settings.state" ]; then
     sudo rm -f /var/local/userspace_speed_settings.state
   fi
   sudo touch /var/local/governor_settings.state
   sudo chmod 777 /var/local/governor_settings.state
   mapfile settings < /var/local/governor_settings.state

   settings[0]="$(cat /sys/devices/platform/${gpu}.gpu/devfreq/${gpu}.gpu/governor)"
   settings[1]="$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor)"
   settings[2]="$(cat /sys/devices/platform/dmc/devfreq/dmc/governor)"

   for j in "${settings[@]}"
   do
     echo $j
   done > /var/local/governor_settings.state

   if [[ "$(cat /sys/devices/platform/${gpu}.gpu/devfreq/${gpu}.gpu/governor)" == "userspace" ]]; then
     sudo touch /var/local/userspace_speed_settings.state
     sudo chmod 777 /var/local/userspace_speed_settings.state
     mapfile usettings < /var/local/userspace_speed_settings.state
     usettings[0]="$(cat /sys/devices/platform/${gpu}.gpu/devfreq/${gpu}.gpu/userspace/set_freq)"
     usettings[1]="$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed)"
     usettings[2]="$(cat /sys/devices/platform/dmc/devfreq/dmc/userspace/set_freq)"
     for j in "${usettings[@]}"
     do
       echo $j
     done > /var/local/userspace_speed_settings.state
   fi

   echo powersave | sudo tee /sys/devices/platform/${gpu}.gpu/devfreq/${gpu}.gpu/governor > /dev/null
   echo powersave | sudo tee /sys/devices/system/cpu/cpufreq/policy0/scaling_governor > /dev/null
   echo powersave | sudo tee /sys/devices/platform/dmc/devfreq/dmc/governor > /dev/null
}

function RestoreSettingsOnWake() {
   if [ -f "/var/local/governor_settings.state" ]; then
     mapfile settings < /var/local/governor_settings.state

     echo ${settings[0]} | sudo tee /sys/devices/platform/${gpu}.gpu/devfreq/${gpu}.gpu/governor > /dev/null &
     echo ${settings[1]} | sudo tee /sys/devices/system/cpu/cpufreq/policy0/scaling_governor > /dev/null &
     echo ${settings[2]} | sudo tee /sys/devices/platform/dmc/devfreq/dmc/governor > /dev/null &

     sudo rm -f /var/local/governor_settings.state
   fi
   if [ -f "/var/local/userspace_speed_settings.state" ]; then
     mapfile usettings < /var/local/userspace_speed_settings.state

     echo ${usettings[0]} | sudo tee /sys/devices/platform/${gpu}.gpu/devfreq/${gpu}.gpu/userspace/set_freq > /dev/null &
     echo ${usettings[1]} | sudo tee /sys/devices/system/cpu/cpufreq/policy0/scaling_setspeed > /dev/null &
     echo ${usettings[2]} | sudo tee /sys/devices/platform/dmc/devfreq/dmc/userspace/set_freq > /dev/null &

     sudo rm -f /var/local/userspace_speed_settings.state
   fi
   if [ "$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor)" == "ondemand" ]; then
     echo 85 | sudo tee -a /sys/devices/system/cpu/cpu*/cpufreq/ondemand/up_threshold > /dev/null &
     echo 150 | sudo tee -a /sys/devices/system/cpu/cpu*/cpufreq/ondemand/sampling_down_factor > /dev/null &
   fi
}

cmd=${1}
shift
$cmd "$1"

exit 0
