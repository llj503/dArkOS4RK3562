#!/bin/sh
# Vita3K-Plus launcher for dArkOS. Expects a Wayland compositor (Weston on DRM)
# to be running already; vita3k-launch.sh takes care of that from ES.
HERE=$(cd "$(dirname "$0")" && pwd)

export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
export QT_PLUGIN_PATH="$HERE/qtplugins"
export QT_QPA_PLATFORM_PLUGIN_PATH="$HERE/qtplugins/platforms"
export LD_LIBRARY_PATH="$HERE/lib:$HERE${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Portable mode keeps config.yml, firmware and installed games inside the
# bundle. On dArkOS /opt/vita3k/portable is a symlink to /roms/vita3k so the
# small rootfs is not filled up by Vita content.
if [ ! -e "$HERE/portable" ]; then
    mkdir -p "$HERE/portable" 2>/dev/null || true
fi

# rk3562-joystick (same mapping the PS2 launcher uses).
export SDL_GAMECONTROLLERCONFIG="${SDL_GAMECONTROLLERCONFIG:-1900a4dd726b333536322d6a6f797300,rk3562-joystick,a:b0,b:b1,x:b3,y:b2,back:b8,start:b9,guide:b10,misc1:b17,leftstick:b11,rightstick:b12,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftshoulder:b4,rightshoulder:b5,lefttrigger:a2,righttrigger:a5,leftx:a0,lefty:a1,rightx:a3,righty:a4,platform:Linux,}"
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-alsa}"
export AUDIODEV="${AUDIODEV:-default}"

# Rockchip's libMali.so statically links libwayland-client/server and exports
# their wl_* symbols. Qt6Gui loads libEGL -> libMali into the global scope before
# the wayland platform plugin is dlopened, so Qt6WaylandClient would bind
# wl_display_connect to Mali's copy, which cannot connect: Qt aborts with
# "Failed to create wl_display (No such file or directory)" even though the
# socket exists. Preloading the real client puts it ahead of libMali.
# psvita-launch.sh does the same; skip it if the launcher already did.
case "${LD_PRELOAD:-}" in
    *libwayland-client*) ;;
    *)
        for c in /lib/aarch64-linux-gnu/libwayland-client.so.0 \
                 /usr/lib/aarch64-linux-gnu/libwayland-client.so.0; do
            if [ -e "$c" ]; then
                export LD_PRELOAD="$c${LD_PRELOAD:+:$LD_PRELOAD}"
                break
            fi
        done
        ;;
esac

exec "$HERE/Vita3K" "$@"
