#!/bin/sh
# rk817-audio-path.sh — 按耳机插入状态设置 RK817 播放路径。
# codec 驱动按 Playback Path 自动控制外部功放 GPIO (SPK 路径开功放,
# HP 路径关功放开耳放), 所以路径必须跟耳机状态一致, 否则无声。
# 触发: hook.sh 每次开机 + 99-rk817-audio.rules 的 extcon 变化事件。
CARD=0
HP=0
for e in /sys/class/extcon/extcon*; do
  [ "$(cat "$e/name" 2>/dev/null)" = "rk817-sound" ] || continue
  for c in "$e"/cable.*; do
    if [ "$(cat "$c/name" 2>/dev/null)" = "HEADPHONE" ]; then
      HP=$(cat "$c/state" 2>/dev/null)
    fi
  done
done
if [ "$HP" = "1" ]; then
  amixer -c $CARD -q sset 'Playback Path' HP
  amixer -c $CARD -q sset Headphone on
else
  amixer -c $CARD -q sset 'Playback Path' SPK
  amixer -c $CARD -q sset Speaker on
fi