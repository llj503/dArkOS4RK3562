#!/bin/bash

sudo msgbox "This process will restore the default retroarch32 settings.  Use this if you can't open the retroarch32 menu anymore.  Be aware that any global setting changes you've changed will be reverted to the default settings as initially set from the most recent update."
my_var=`osk "Enter OK here to proceed." | tail -n 1`

if [[ $my_var = OK ]] || [[ $my_var = ok ]] ; then
  cp /home/ark/.config/retroarch32/retroarch.cfg.bak /home/ark/.config/retroarch32/retroarch.cfg
else
  sudo msgbox "You didn't type OK.  This script will exit now and no changes have been made from this process."
  printf "You didn't type OK.  This script will exit now and no changes have been made from this process." | tee -a "$LOG_FILE"
fi
