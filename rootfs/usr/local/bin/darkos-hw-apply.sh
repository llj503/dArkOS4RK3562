#!/bin/bash
# darkos-hw-apply -- ES 启动时应用 LED / 风扇持久化配置 (取代 systemd 服务)
# 由 EmulationStation 启动时通过 sudo 调用一次
# timeout: 任何后端异常都不允许阻塞 ES 启动 (window.init 之前同步调用)

# 上一轮 ES 遗留的 fluidsynth 会一直占着 hw:0,0, 新 ES 打不开音频 (无声).
# 此时 ES 还没开始播放, 清掉残留是安全的.
pkill -f fluidsynth 2>/dev/null || true

# ES 退出时会把背光写成 0; 重启 ES 后 brightness-watch 不会重放, 屏幕会黑.
# 这里按上次保存的亮度恢复 (<20 视为息屏调暗, 不恢复).
BL_CFG=/home/ark/.config/brightness.level
BL_SYS=/sys/class/backlight/backlight/brightness
if [ -r "$BL_CFG" ] && [ -w "$BL_SYS" ]; then
  BL=$(cat "$BL_CFG" 2>/dev/null || true)
  case "$BL" in
    ''|*[!0-9]*) ;;
    *) [ "$BL" -ge 20 ] && echo "$BL" > "$BL_SYS" ;;
  esac
fi

[ -x /usr/local/bin/ledctl ] && timeout 5 /usr/local/bin/ledctl apply
[ -x /usr/local/bin/fanctl ] && timeout 5 /usr/local/bin/fanctl apply
exit 0
