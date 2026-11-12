#!/bin/bash

if [[ $1 == "standalone" ]]; then
    directory=$(dirname "$2" | cut -d "/" -f2)
    # 配置放 roms 分区 (flycast 式软链)
    CFG_DIR="/$directory/doom/lzdoom"
    mkdir -p "$CFG_DIR"
    if [ -d "$HOME/.config/lzdoom" ] && [ ! -L "$HOME/.config/lzdoom" ]; then
      cp -a "$HOME/.config/lzdoom/." "$CFG_DIR/" 2>/dev/null
      rm -rf "$HOME/.config/lzdoom"
    fi
    ln -sfn "$CFG_DIR" "$HOME/.config/lzdoom"
    [ -f "$CFG_DIR/lzdoom.ini" ] || cp /opt/lzdoom/lzdoom.ini.template "$CFG_DIR/lzdoom.ini"
    echo "VAR=lzdoom" > /home/ark/.config/KILLIT
    sudo systemctl restart killer_daemon.service
	if [ ".$(echo "$2"| cut -d. -f2)" == ".sh" ] || [ ".$(echo "$2"| cut -d. -f2)" == ".SH" ]; then
	dos2unix "${2}"
        "$2"
	elif [ ".$(echo "$2"| cut -d. -f2)" == ".doom" ] || [ ".$(echo "$2"| cut -d. -f2)" == ".DOOM" ]; then
	  IWAD=""; MODS=""; DEH=""; SAVE=""; CONF=""; PARAMS=""; DOOM_BASE_DIR="/$directory/doom/"
	  dos2unix "${2}"
	  while IFS== read -r key value; do
	    if [ "$key" == "IWAD" ]; then IWAD+=" ${DOOM_BASE_DIR}${value}"
	    elif [ "$key" == "MOD" ]; then MODS+=" ${DOOM_BASE_DIR}${value}"
	    elif [ "$key" == "CONF" ]; then CONF+=" ${DOOM_BASE_DIR}${value}"
	    elif [ "$key" == "SAVE" ]; then SAVE+=" ${DOOM_BASE_DIR}${value}"
	    elif [ "$key" == "DEH" ]; then DEH+=" ${DOOM_BASE_DIR}${value}"
	    fi
	  done < "${2}"
	  if [ "$IWAD" ]; then PARAMS+=" -iwad ${IWAD:1}"; fi
	  if [ "$MODS" ]; then PARAMS+=" -file ${MODS:1}"; fi
	  if [ "$SAVE" ]; then PARAMS+=" -savedir ${SAVE:1}"; fi
	  if [ "$CONF" ]; then PARAMS+=" -config ${CONF:1}"; fi
	  if [ "$DEH" ]; then PARAMS+=" -deh ${DEH:1}"; fi
	  /opt/lzdoom/lzdoom ${PARAMS:1}
	else
	/opt/lzdoom/lzdoom -iwad "$2"
	fi
    sudo systemctl stop killer_daemon.service
    sudo systemctl restart ogage &
elif [[ $1 == "standalone-gzdoom" ]]; then
        directory=$(dirname "$2" | cut -d "/" -f2)
        # 配置放 roms 分区 (flycast 式软链)
        CFG_DIR="/$directory/doom/gzdoom"
        mkdir -p "$CFG_DIR"
        if [ -d "$HOME/.config/gzdoom" ] && [ ! -L "$HOME/.config/gzdoom" ]; then
          cp -a "$HOME/.config/gzdoom/." "$CFG_DIR/" 2>/dev/null
          rm -rf "$HOME/.config/gzdoom"
        fi
        ln -sfn "$CFG_DIR" "$HOME/.config/gzdoom"
        [ -f "$CFG_DIR/gzdoom.ini" ] || cp /opt/gzdoom/gzdoom.ini.template "$CFG_DIR/gzdoom.ini"
        echo "VAR=gzdoom" > /home/ark/.config/KILLIT
        sudo systemctl restart killer_daemon.service
        if [ ".$(echo "$2"| cut -d. -f2)" == ".sh" ] || [ ".$(echo "$2"| cut -d. -f2)" == ".SH" ]; then
        dos2unix "${2}"
        "$2"
        elif [ ".$(echo "$2"| cut -d. -f2)" == ".doom" ] || [ ".$(echo "$2"| cut -d. -f2)" == ".DOOM" ]; then
          IWAD=""; MODS=""; DEH=""; SAVE=""; CONF=""; PARAMS=""; DOOM_BASE_DIR="/$directory/doom/"
          dos2unix "${2}"
          while IFS== read -r key value; do
            if [ "$key" == "IWAD" ]; then IWAD+=" ${DOOM_BASE_DIR}${value}"
            elif [ "$key" == "MOD" ]; then MODS+=" ${DOOM_BASE_DIR}${value}"
            elif [ "$key" == "CONF" ]; then CONF+=" ${DOOM_BASE_DIR}${value}"
            elif [ "$key" == "SAVE" ]; then SAVE+=" ${DOOM_BASE_DIR}${value}"
            elif [ "$key" == "DEH" ]; then DEH+=" ${DOOM_BASE_DIR}${value}"
            fi
          done < "${2}"
          if [ "$IWAD" ]; then PARAMS+=" -iwad ${IWAD:1}"; fi
          if [ "$MODS" ]; then PARAMS+=" -file ${MODS:1}"; fi
          if [ "$SAVE" ]; then PARAMS+=" -savedir ${SAVE:1}"; fi
          if [ "$CONF" ]; then PARAMS+=" -config ${CONF:1}"; fi
          if [ "$DEH" ]; then PARAMS+=" -deh ${DEH:1}"; fi
          /opt/gzdoom/gzdoom ${PARAMS:1} +gl_es 1 +vid_preferbackend 3 +cl_capfps 0
        else
        /opt/gzdoom/gzdoom -iwad "$2" +gl_es 1 +vid_preferbackend 3 +cl_capfps 0
        fi
        sudo systemctl stop killer_daemon.service
        sudo systemctl restart ogage &
else
  /usr/local/bin/"$1" -L /home/ark/.config/"$1"/cores/"$2"_libretro.so "$3"
fi

