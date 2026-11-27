#!/bin/bash
# Azahar Qt 前端在 dArkOS 上的启动器，安装为 /opt/azahar/run.sh。
# ES 持有 DRM master，因此先离开 ES 的 cgroup，再停 ES、起 Weston、以 ark 运行 Azahar。
set -u

ROM="${1:-}"

case "$ROM" in
    *.sh|*.SH) exec bash "$ROM" ;;
esac

B=/opt/azahar
WESTON_HOME=/opt/vita3k/weston
DATA=/roms/3ds/azahar
RTDIR=/run/azahar-qt
SOCK=wayland-azahar

if [ "${AZAHAR_QT_SESSION:-}" != "1" ]; then
    sudo systemctl reset-failed azahar-qt-session.service 2>/dev/null || true
    exec sudo systemd-run --unit=azahar-qt-session --collect \
        --setenv=AZAHAR_QT_SESSION=1 \
        --setenv=AZAHAR_EXTRA_ARGS="${AZAHAR_EXTRA_ARGS:-}" \
        --working-directory=/home/ark \
        /opt/azahar/run.sh "$ROM"
fi

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ ! -x "$B/azahar-qt" ]; then
    echo "azahar-qt: $B/azahar-qt is missing" >&2
    systemctl start emulationstation
    exit 1
fi

DEVICE=$(cat /home/ark/.config/.DEVICE 2>/dev/null || true)
if [ -n "$ROM" ]; then
    partition=$(dirname "$ROM" | cut -d/ -f2)
    [ -n "$partition" ] && DATA="/$partition/3ds/azahar"
fi
mkdir -p "$DATA/share" "$DATA/config" "$DATA/cache" "$DATA/logs"
chown ark:ark "$DATA" "$DATA/share" "$DATA/config" "$DATA/cache" "$DATA/logs" 2>/dev/null || true

WESTON_PID=
GOV_CPU=
GOV_GPU=
GOV_DMC=
GPU_DEVFREQ=
BL_SYS=/sys/class/backlight/backlight/brightness
BL_SAVED=
PLAYBACK_PATH=$(amixer sget 'Playback Path' 2>/dev/null | sed -n "s/.*Item0: '\(.*\)'/\1/p")

restore_brightness() {
    [ -n "$BL_SAVED" ] && [ -w "$BL_SYS" ] && echo "$BL_SAVED" > "$BL_SYS" 2>/dev/null
    return 0
}

set_governors() {
    local cpu=/sys/devices/system/cpu/cpufreq/policy0/scaling_governor
    local dmc=/sys/devices/platform/dmc/devfreq/dmc/governor
    local d
    for d in /sys/class/devfreq/*.gpu; do
        [ -e "$d" ] && GPU_DEVFREQ="$d/governor" && break
    done
    [ -r "$cpu" ] && GOV_CPU=$(cat "$cpu")
    [ -n "$GPU_DEVFREQ" ] && [ -r "$GPU_DEVFREQ" ] && GOV_GPU=$(cat "$GPU_DEVFREQ")
    [ -r "$dmc" ] && GOV_DMC=$(cat "$dmc")
    local target path want
    for target in "$cpu:performance" "$GPU_DEVFREQ:performance" "$dmc:performance"; do
        path=${target%%:*} want=${target##*:}
        [ -n "$path" ] && [ -w "$path" ] || continue
        grep -qw "$want" "${path%governor}available_governors" 2>/dev/null || continue
        echo "$want" > "$path" 2>/dev/null || true
    done
}

restore_governors() {
    [ -n "$GOV_CPU" ] && echo "$GOV_CPU" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null
    [ -n "$GOV_GPU" ] && [ -n "$GPU_DEVFREQ" ] && echo "$GOV_GPU" > "$GPU_DEVFREQ" 2>/dev/null
    [ -n "$GOV_DMC" ] && echo "$GOV_DMC" > /sys/devices/platform/dmc/devfreq/dmc/governor 2>/dev/null
    return 0
}

cleanup() {
    if [ -n "$WESTON_PID" ]; then
        kill "$WESTON_PID" 2>/dev/null
        for _ in $(seq 1 20); do
            kill -0 "$WESTON_PID" 2>/dev/null || break
            sleep 0.2
        done
        kill -9 "$WESTON_PID" 2>/dev/null
    fi
    rm -f "$RTDIR/$SOCK" "$RTDIR/$SOCK.lock"
    restore_governors
    systemctl restart killer_daemon.service >/dev/null 2>&1 || true
    systemctl restart ogage.service >/dev/null 2>&1 || true
    systemctl start emulationstation
    sleep 1
    restore_brightness
    if [ "$DEVICE" = "RG52MINI" ] || [ "$DEVICE" = "RG56PRO" ] || [ "$DEVICE" = "RG43H" ]; then
        default_path=SPK
        [ "$DEVICE" = "RG52MINI" ] || default_path=HP
        amixer -q sset 'Playback Path' "${PLAYBACK_PATH:-$default_path}" 2>/dev/null
        amixer -q sset 'Resume Path' ON 2>/dev/null
    fi
}
trap cleanup EXIT

systemctl stop emulationstation
sleep 2
[ -r "$BL_SYS" ] && BL_SAVED=$(cat "$BL_SYS")
if [ -z "$BL_SAVED" ] || ! [ "$BL_SAVED" -gt 0 ] 2>/dev/null; then
    BL_SAVED=200
fi
set_governors

mkdir -p "$RTDIR"
chown ark:ark "$RTDIR"
chmod 0700 "$RTDIR"
rm -f "$RTDIR/$SOCK" "$RTDIR/$SOCK.lock"
export XDG_RUNTIME_DIR="$RTDIR"

SCREEN_ROTATION=0
GEOM=$(/usr/local/bin/console_detect -s 2>/dev/null || true)
[ -n "$GEOM" ] && eval "$GEOM"
TFORM=normal
case "${SCREEN_ROTATION:-0}" in
    90) TFORM=rotate-270 ;;
    180) TFORM=rotate-180 ;;
    270) TFORM=rotate-90 ;;
esac
OUTPUT=DSI-1
for status in /sys/class/drm/card*-*/status; do
    [ -r "$status" ] && [ "$(cat "$status" 2>/dev/null)" = connected ] || continue
    case "$status" in
        *-DSI-*) OUTPUT=$(basename "$(dirname "$status")"); OUTPUT=${OUTPUT#card*-}; break ;;
    esac
done
mkdir -p "$RTDIR/xdg/weston"
printf '[output]\nname=%s\ntransform=%s\n' "$OUTPUT" "$TFORM" > "$RTDIR/xdg/weston.ini"
cp "$RTDIR/xdg/weston.ini" "$RTDIR/xdg/weston/weston.ini"
chmod 0644 "$RTDIR/xdg/weston.ini" "$RTDIR/xdg/weston/weston.ini"

LD_LIBRARY_PATH="$WESTON_HOME/lib" XDG_CONFIG_HOME="$RTDIR/xdg" \
    "$WESTON_HOME/bin/weston" --backend=drm-backend.so --shell=kiosk-shell.so --idle-time=0 \
    --socket="$SOCK" --log="$DATA/logs/weston.log" >"$DATA/logs/weston.out" 2>&1 &
WESTON_PID=$!
for _ in $(seq 1 60); do
    [ -S "$RTDIR/$SOCK" ] && break
    kill -0 "$WESTON_PID" 2>/dev/null || break
    sleep 0.25
done
if [ ! -S "$RTDIR/$SOCK" ]; then
    echo "azahar-qt: Weston did not come up, see $DATA/logs/weston.log" >&2
    exit 1
fi
chmod 0666 "$RTDIR/$SOCK"
restore_brightness

# 图形接口与 Vulkan 设备由 OSD 写入 qt-config.ini，启动器不再覆盖。
CFG="$DATA/config/azahar-emu/qt-config.ini"
mkdir -p "$DATA/config/azahar-emu/custom"
python3 - "$CFG" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = path.read_text().splitlines() if path.exists() else []

def set_value(section, key, value):
    global lines
    start = next((i for i, line in enumerate(lines) if line.strip() == f"[{section}]"), None)
    if start is None:
        if lines and lines[-1]:
            lines.append("")
        start = len(lines)
        lines.append(f"[{section}]")
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("[")), len(lines))
    if isinstance(value, str):
        value = value.replace("\\", "\\\\").replace('"', '\\"')
        rendered = f'"{value}"' if "," in value else value
    elif isinstance(value, bool):
        rendered = str(value).lower()
    else:
        rendered = str(value)
    index = next((i for i in range(start + 1, end) if lines[i].startswith(key + "=")), None)
    if index is None:
        lines.insert(end, f"{key}={rendered}")
    else:
        lines[index] = f"{key}={rendered}"

guid = "1900a4dd726b333536322d6a6f797300"
base = f"engine:sdl,guid:{guid},port:0,api:controller"
set_value("Controls", "profile", 0)
set_value("Controls", "profiles\\size", 1)
set_value("Controls", "profiles\\1\\name", "dArkOS")
set_value("Controls", "profiles\\1\\input_maptype", 2)
for key, button in {
    "button_a": 0,
    "button_b": 1,
    "button_x": 2,
    "button_y": 3,
    "button_up": 26,
    "button_down": 27,
    "button_left": 28,
    "button_right": 29,
    "button_l": 9,
    "button_r": 10,
    "button_start": 6,
    "button_select": 4,
    "button_debug": 15,
    "button_home": 5,
}.items():
    set_value("Controls", f"profiles\\1\\{key}", f"{base},button:{button}")
    set_value("Controls", f"profiles\\1\\{key}\\default", False)
for key, axis in (("button_zl", 4), ("button_zr", 5)):
    set_value("Controls", f"profiles\\1\\{key}",
              f"{base},axis:{axis},direction:+,threshold:0.5")
    set_value("Controls", f"profiles\\1\\{key}\\default", False)
for key, axis_x, axis_y in (("circle_pad", 0, 1), ("c_stick", 2, 3)):
    set_value("Controls", f"profiles\\1\\{key}",
              f"{base},axis_x:{axis_x},axis_y:{axis_y},deadzone:0.100000")
    set_value("Controls", f"profiles\\1\\{key}\\default", False)

path.write_text("\n".join(lines) + "\n")
PY
chown ark:ark "$DATA/config/azahar-emu" "$DATA/config/azahar-emu/custom" "$CFG" 2>/dev/null || true

# Azahar 的 SDL 直接读 evdev；Weston/libinput 会忽略手柄，不需要 uinput 映射器。
export SDL_GAMECONTROLLERCONFIG="1900a4dd726b333536322d6a6f797300,rk3562-joystick,a:b1,b:b0,x:b2,y:b3,back:b8,start:b9,guide:b10,misc1:b17,leftstick:b11,rightstick:b12,dpup:b26,dpdown:b27,dpleft:b28,dpright:b29,leftshoulder:b4,rightshoulder:b5,lefttrigger:a2,righttrigger:a5,leftx:a0,lefty:a1,rightx:a3,righty:a4,platform:Linux,"
echo "VAR=azahar-qt" > /home/ark/.config/KILLIT
systemctl restart killer_daemon.service >/dev/null 2>&1 || true

WL_CLIENT=
for candidate in /lib/aarch64-linux-gnu/libwayland-client.so.0 /usr/lib/aarch64-linux-gnu/libwayland-client.so.0; do
    [ -e "$candidate" ] && WL_CLIENT="$candidate" && break
done
if [ -z "$WL_CLIENT" ]; then
    echo "azahar-qt: libwayland-client.so.0 not found" >&2
    exit 1
fi

read -r -a EXTRA <<< "${AZAHAR_EXTRA_ARGS:-}"
ARGS=()
[ -n "$ROM" ] && ARGS+=(-f "$ROM")
ARGS+=("${EXTRA[@]}")

# libmali 没有 Wayland Vulkan WSI，用 vita3k 的 WSI 层补 surface 支持。
# 该层是隐式层，VK_LAYER_PATH 枚举不到，必须用 VK_ADD_IMPLICIT_LAYER_PATH。
VK_LAYER_ENV=()
if [ -r /opt/vita3k/wsi/VkLayer_window_system_integration.json ]; then
    VK_LAYER_ENV=(VK_ADD_IMPLICIT_LAYER_PATH=/opt/vita3k/wsi)
fi

# 全屏 WSI 子表面遮挡主窗口后，Weston 不再回主窗口的 frame callback；
# Qt 6.8 收到超时就把主窗口标成不可见，之后 OSD 子表面重开时不再发 expose。
# 禁用该超时，避免 OSD 第二次打开起不上屏。
QT_WAYLAND_ENV=(QT_WAYLAND_FRAME_CALLBACK_TIMEOUT=0)

# Vulkan 驱动由 OSD 视频页写入 [vulkan] driver；malisx2 需要显式指定 ICD。
VK_ICD_ENV=()
VK_DRIVER=$(sed -n '/^\[vulkan\]/,/^\[/s/^driver=//p' \
    "$DATA/config/azahar-emu/osd.ini" 2>/dev/null | head -1)
if [ "$VK_DRIVER" = "malisx2" ]; then
    for icd in /opt/malisx2-0.6.1/malisx2.json /opt/malisx2/malisx2.json; do
        if [ -r "$icd" ]; then
            VK_ICD_ENV=(VK_DRIVER_FILES="$icd")
            break
        fi
    done
    if [ ${#VK_ICD_ENV[@]} -eq 0 ]; then
        echo "azahar-qt: malisx2 未安装，使用系统 Vulkan ICD" >&2
    fi
fi

runuser -u ark -- env \
    HOME=/home/ark USER=ark LOGNAME=ark \
    XDG_RUNTIME_DIR="$RTDIR" WAYLAND_DISPLAY="$SOCK" \
    QT_QPA_PLATFORM=wayland \
    XDG_DATA_HOME="$DATA/share" XDG_CONFIG_HOME="$DATA/config" XDG_CACHE_HOME="$DATA/cache" \
    LD_LIBRARY_PATH="$B/libs:/usr/local/lib" QT_PLUGIN_PATH="$B/qt-plugins" \
    FONTCONFIG_FILE="$B/fonts.conf" LD_PRELOAD="$WL_CLIENT" \
    SDL_AUDIODRIVER=alsa SDL_GAMECONTROLLERCONFIG="$SDL_GAMECONTROLLERCONFIG" \
    "${QT_WAYLAND_ENV[@]}" \
    "${VK_LAYER_ENV[@]}" \
    "${VK_ICD_ENV[@]}" \
    "$B/azahar-qt" "${ARGS[@]}" >"$DATA/logs/azahar-qt.log" 2>&1
