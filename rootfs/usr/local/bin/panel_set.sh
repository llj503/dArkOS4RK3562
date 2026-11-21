#!/bin/bash
# panel_set.sh -- 面板 BCSH (亮度/对比度/饱和度/色调), 0-100, 50 为中性
#   panel_set.sh get_<prop>          读当前值 (无驱动支持时输出 50)
#   panel_set.sh set_<prop> <0-100>  设置并保存
#   panel_set.sh apply               开机/ES 启动时恢复保存值
# prop: brightness | contrast | saturation | hue
# 底层: rockchipdrm 模块参数 bcs_* -> VOP2 BCSH (RGB 输出, 游戏内也保持)
PARAM=/sys/module/rockchipdrm/parameters
CFG=/home/ark/.config/panel_bcs

is_prop() {
	case "$1" in
	brightness|contrast|saturation|hue) return 0 ;;
	esac
	return 1
}

read_prop() {
	local v
	v=$(cat "$PARAM/bcs_$1" 2>/dev/null) || v=50
	case "$v" in
	''|*[!0-9]*) v=50 ;;
	esac
	echo "$v"
}

save() {
	local p
	mkdir -p "$(dirname "$CFG")"
	: > "$CFG.tmp"
	for p in brightness contrast saturation hue; do
		printf '%s=%s\n' "$p" "$(read_prop "$p")" >> "$CFG.tmp"
	done
	mv -f "$CFG.tmp" "$CFG"
	chown ark:ark "$CFG" 2>/dev/null
}

case "$1" in
get_*)
	p=${1#get_}
	is_prop "$p" || exit 2
	read_prop "$p"
	;;
set_*)
	p=${1#set_}
	is_prop "$p" || exit 2
	v=${2:-}
	case "$v" in
	''|*[!0-9]*) echo "usage: $0 set_$p <0-100>" >&2; exit 2 ;;
	esac
	[ "$v" -gt 100 ] && v=100
	printf '%s\n' "$v" > "$PARAM/bcs_$p" || exit 1
	save
	;;
apply)
	for p in brightness contrast saturation hue; do
		v=$(sed -n "s/^$p=//p" "$CFG" 2>/dev/null | tail -n 1)
		case "$v" in
		''|*[!0-9]*) continue ;;
		esac
		printf '%s\n' "$v" > "$PARAM/bcs_$p" 2>/dev/null || true
	done
	;;
reset)
	for p in brightness contrast saturation hue; do
		printf '50\n' > "$PARAM/bcs_$p" 2>/dev/null || true
	done
	save
	;;
*)
	echo "usage: $0 {get_<prop>|set_<prop> <0-100>|apply|reset}" >&2
	exit 2
	;;
esac
exit 0
