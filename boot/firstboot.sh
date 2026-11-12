#!/bin/bash
# dArkOS 首启/开机入口 (firstboot.service, 每次开机执行)
#   1. hook.sh — 机型检测/DTB 变化比较/quirks 全量应用 (含 SDL2/SDL3 旋转库)
#      必须先于扩容执行: 扩容可能超时被杀或 p5 已是 exfat 秒退,
#      旧逻辑把 hook 挂在扩容成功路径末尾, 导致首启 SDL 永不复制。
#   2. select_language — 首启语言选择 (默认英文, 可选中文)
#   3. expandtoexfat.sh — 仅首启真正扩容 (p5 已是 exfat 则提升 hook 后秒退)
/boot/hook.sh

select_language() {
    local done_flag=/home/ark/.config/.lang_selected
    [ -f "$done_flag" ] && return 0

    local choice="1"
    if [ -e /dev/tty1 ]; then
        command -v dialog >/dev/null 2>&1 || { touch "$done_flag"; return 0; }

        chmod 666 /dev/uinput 2>/dev/null
        if [ -x /opt/inttools/gptokeyb ]; then
            SDL_GAMECONTROLLERCONFIG_FILE=/opt/inttools/gamecontrollerdb.txt \
                /opt/inttools/gptokeyb -1 "firstboot" -c /opt/inttools/keys.gptk \
                >/dev/null 2>&1 &
            local gpid=$!
        fi

        choice=$(dialog --clear --no-collapse \
            --title "Language / 语言" \
            --default-item 1 --cancel-label "English" --timeout 20 \
            --menu "Choose your language / 选择语言" 16 56 4 \
            1 "English (default)" \
            2 "中文 (简体)" \
            2>&1 >/dev/tty1) || choice="1"

        [ -n "$gpid" ] && kill "$gpid" 2>/dev/null
        printf '\033c' > /dev/tty1
    fi

    local settings=/home/ark/.emulationstation/es_settings.cfg
    mkdir -p /home/ark/.config

    if [ "$choice" = "2" ]; then
        touch /home/ark/.config/.cn
        [ -f "$settings" ] && sed -i 's|name="Language" value="[^"]*"|name="Language" value="zh-CN"|' "$settings" 2>/dev/null
    else
        rm -f /home/ark/.config/.cn
        [ -f "$settings" ] && sed -i 's|name="Language" value="[^"]*"|name="Language" value="en"|' "$settings" 2>/dev/null
    fi

    touch "$done_flag"
    chown 1000:1000 "$done_flag" 2>/dev/null || true
}

select_language

timeout 600 /boot/expandtoexfat.sh > /dev/tty1 2>&1
