#!/bin/bash

sudo msgbox "This process will restore the default retroarch32 core options.  Use this if you can't launch certain retroarch32 emulators (ex. Duckstation) after changing default core options.  Be aware that any global core option changes you've changed will be reverted to the default options as initially set from the most recent update."
my_var=`osk "Enter OK here to proceed." | tail -n 1`

if [[ $my_var = OK ]] || [[ $my_var = ok ]] ; then
  cp /home/ark/.config/retroarch32/retroarch-core-options.cfg.bak /home/ark/.config/retroarch32/retroarch-core-options.cfg
else
  sudo msgbox "You didn't type OK.  This script will exit now and no changes have been made from this process."
  printf "You didn't type OK.  This script will exit now and no changes have been made from this process." | tee -a "$LOG_FILE"
fi
