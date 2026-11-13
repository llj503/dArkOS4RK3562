#!/bin/bash
# dArkOS 首启/开机入口 (firstboot.service, 每次开机执行)
#   1. hook.sh — 机型检测/DTB 变化比较/quirks 全量应用 (含 SDL2/SDL3 旋转库),
#      同时按 /boot/.cn 应用语言; 必须先于扩容执行: 扩容可能超时被杀或 p5
#      已是 exfat 秒退, 旧逻辑把 hook 挂在扩容成功路径末尾, 导致首启 SDL 永不复制。
#   2. expandtoexfat.sh — 仅首启真正扩容 (p5 已是 exfat 则提升 hook 后秒退)
# 语言不再在机身上选择: PC 端 dtbselector 选中文会写 /boot/.cn (内容 zh-CN),
# 选 English 会删掉它, hook 读这个标记写 ES/RetroArch/PPSSPP。
/boot/hook.sh

timeout 600 /boot/expandtoexfat.sh > /dev/tty1 2>&1
