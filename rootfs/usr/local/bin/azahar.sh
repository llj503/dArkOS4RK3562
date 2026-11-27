#!/bin/bash
# Azahar (3DS) 唯一启动入口。EmulationStation 以
#   azahar.sh %EMULATOR% %ROM%
# 调用；%EMULATOR% 为空/retroarch/azahar 走 libretro 核心，azahar-qt 走独立前端。
# 两条路径都先经过 azahar-dec.sh：按需解密 CIA/CCI，安装 update/DLC 和共享字库。
set -u

MODE="${AZAHAR_MODE:-}"

if [ -z "$MODE" ]; then
	emu="${1:-}"
	case "$emu" in
	azahar-qt)
		rom="${2:-}"
		[ -n "$rom" ] || { echo "azahar.sh: missing ROM" >&2; exit 2; }
		partition=$(dirname "$rom" | cut -d/ -f2)
		[ -n "$partition" ] || partition=roms
		export AZAHAR_MODE=qt
		export AZAHAR_BIN=/opt/azahar/run.sh
		export AZAHAR_USER_DIR="/$partition/3ds/azahar/share/azahar-emu"
		exec /usr/local/bin/azahar-dec.sh "$rom"
		;;
	"" | retroarch | azahar)
		rom="${2:-}"
		;;
	*)
		# %EMULATOR% 展开为空时，ES 可能只把 ROM 作为第一个参数传进来
		if [ -z "${2:-}" ] && [ -n "$emu" ] && [ -e "$emu" ]; then
			rom="$emu"
		else
			echo "azahar.sh: unknown emulator '$emu' (use retroarch or azahar-qt)" >&2
			exit 1
		fi
		;;
	esac
	[ -n "$rom" ] || { echo "azahar.sh: missing ROM" >&2; exit 2; }
	export AZAHAR_MODE=core
	export AZAHAR_BIN=/usr/local/bin/azahar.sh
	exec /usr/local/bin/azahar-dec.sh "$rom"
fi

# azahar-dec.sh 解密完成后会 exec AZAHAR_BIN，并把最终 ROM 作为 $1 传回来。
rom="${1:-}"
[ -n "$rom" ] || { echo "azahar.sh: missing ROM after decryption" >&2; exit 2; }

if [ "$MODE" = qt ]; then
	exec /opt/azahar/run.sh "$rom"
fi

# libretro 核心路径：RetroArch 的 gl 驱动下核心会 shader 失败崩溃，必须走 Vulkan；
# Mali 官方 blob 没有 KHR_display，用自编 malisx2。
export VK_ICD_FILENAMES=/opt/malisx2/malisx2.json
CFG=/tmp/azahar-video.cfg
printf 'video_driver = "vulkan"\nsavefiles_in_content_dir = "false"\n' > "$CFG"
exec /usr/local/bin/retroarch -c /home/ark/.config/retroarch/retroarch.cfg \
	--appendconfig "$CFG" \
	-L /home/ark/.config/retroarch/cores/azahar_libretro.so "$rom"
