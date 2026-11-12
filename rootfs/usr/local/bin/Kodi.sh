#!/bin/bash

#if [ -z "$(grep importlib_metadata /home/ark/.kodi/addons/script.module.urllib3/lib/urllib3/http2/__init__.py | tr -d '\0')" ]; then
  #sed -i '/from importlib.metadata import version/c\try:\n  from importlib.metadata import version\nexcept:\n  from importlib_metadata import version' /home/ark/.kodi/addons/script.module.urllib3/lib/urllib3/http2/__init__.py
#fi

export KODI_HOME=/opt/kodi/share/kodi
# dArkOS3562 Kodi is built with a static Python 3.11 (no system libpython).
# Its stdlib is shipped at /opt/kodi/lib/python3.11, so PYTHONHOME=/opt/kodi.
export PYTHONHOME=/opt/kodi

#Set interactive governor to keep kodi performance smooth
sudo perfmax kodi

# Fix wasting RAM due to fragmentation
export MALLOC_MMAP_THRESHOLD_=131072

# Change owner of volume keys or Kodi will grab them
#if [ "$(cat ~/.config/.DEVICE)" != "RG503" ]; then
  if [[ -e "/dev/input/by-path/platform-fe5b0000.i2c-event" ]]; then
    sudo chown root:root /dev/input/event3
  else
    sudo chown root:root /dev/input/event2
  fi
  sudo chown root:root /dev/input/event0
#else
 #sudo chown root:root /dev/input/event1
#fi

printf "\n\n\e[32mStarting Kodi.  Please wait..."
#export LD_LIBRARY_PATH=/opt/kodi/libs/:/opt/kodi/libs/samba

# dArkOS3562: panel rotation from console_detect -> Kodi RGA blit rotation
# (KODI_VIDEO_ROTATION=0/90/180/270; portrait panels render landscape and
# every frame is rotated through RGA into the scanout buffer)
if [[ -x /usr/local/bin/console_detect ]]; then
  eval "$(/usr/local/bin/console_detect -s 2>/dev/null)"
  export KODI_VIDEO_ROTATION="${SCREEN_ROTATION:-0}"
  echo "Kodi rotation: ${KODI_VIDEO_ROTATION}"
fi

cd /opt/kodi
sudo /opt/quitter/oga_controls kodi-gbm rg503 &

if [[ ! -d "/home/ark/.kodi" ]]; then
  mkdir /home/ark/.kodi
  cp -R /opt/kodi/userdata/ /home/ark/.kodi/
fi

# 跟随 ES 语言 (与 flycast/yabasanshiro/ARMSX2 同一套判定)
if grep -q '<string name="Language" value="zh-CN" />' /home/ark/.emulationstation/es_settings.cfg 2>/dev/null; then
  KODI_LOCALE=resource.language.zh_cn
else
  KODI_LOCALE=resource.language.en_gb
fi

# dArkOS3562: the PRIME decoder emits dma-buf frames that bypass the GLES
# renderer and therefore the RGA rotation; decode through RKMPP to NV12 instead.
GS=/home/ark/.kodi/userdata/guisettings.xml
if [[ -f "$GS" ]]; then
  sed -i -E 's#(<setting id="videoplayer\.useprimedecoder"[^>]*>)[^<]*(</setting>)#\1false\2#' "$GS"
  sed -i -E "s#(<setting id=\"locale\.language\"[^>]*>)[^<]*(</setting>)#\1${KODI_LOCALE}\2#" "$GS"
fi

# JSON-RPC TCP 固定 9090, 和 HTTP 的 services.webserverport (8081) 不是一个端口
KODI_PORT=9090

/opt/kodi/lib/kodi/kodi-gbm &
KODI_PID=$!

# 语言包默认 disabled, Kodi 启动时会把 locale.language 重置回默认英文;
# 起来后通过本地 JSON-RPC 启用对应语言包并应用, 每次启动都跟随 ES 语言。
(
  for _ in $(seq 1 60); do
    sleep 1
    kill -0 "$KODI_PID" 2>/dev/null || exit 0
    if exec 3<>/dev/tcp/127.0.0.1/$KODI_PORT 2>/dev/null; then
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"Addons.SetAddonEnabled\",\"params\":{\"addonid\":\"${KODI_LOCALE}\",\"enabled\":true}}" >&3
      printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"Settings.SetSettingValue\",\"params\":{\"setting\":\"locale.language\",\"value\":\"${KODI_LOCALE}\"}}" >&3
      sleep 1
      exec 3>&- 3<&-
      exit 0
    fi
  done
) &

wait "$KODI_PID"

# Make sure quitter is killed if exiting Kodi through the menu
# or ES navigation will be wonky.
if [[ ! -z $(pidof oga_controls) ]]; then
  sudo kill -9 $(pidof oga_controls)
fi

#Set ondemand governor to preserve battery life
sudo perfnorm

# Restart global hotkey deamon just in case it was impacted by the quitter
sudo systemctl restart ogage &

# Clean up screen when done
printf "\033c" >> /dev/tty1
