#!/bin/bash
# remote-services {on|off|status} -- SSH / Samba / FileBrowser / NTP 一键开关
# ES 的"远程服务"开关直接调用; 取代 /opt/system/Enable|Disable Remote Services.sh
case "$1" in
	on)
		systemctl enable --now NetworkManager-wait-online 2>/dev/null
		timedatectl set-ntp 1 2>/dev/null
		systemctl enable --now smbd nmbd ssh 2>/dev/null
		pgrep -x filebrowser >/dev/null 2>&1 || \
			filebrowser -a 0.0.0.0 -p 80 -d /home/ark/.config/filebrowser.db -r / >/dev/null 2>&1 &
		echo 1
		;;
	off)
		systemctl disable --now NetworkManager-wait-online 2>/dev/null
		timedatectl set-ntp 0 2>/dev/null
		systemctl stop smbd nmbd ssh 2>/dev/null
		pkill -x filebrowser 2>/dev/null
		echo 0
		;;
	status)
		if systemctl is-active --quiet ssh && systemctl is-active --quiet smbd; then
			echo 1
		else
			echo 0
		fi
		;;
	*)
		echo "usage: remote-services {on|off|status}" >&2
		exit 2
		;;
esac
exit 0
