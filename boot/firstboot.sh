#!/bin/bash
# dArkOS 首启/开机入口 (firstboot.service, 每次开机执行)
#   1. expandtoexfat.sh — 首启扩容 /roms 并解包 roms.tar (p5 已是 exfat 则秒退,
#      同时把 hook.sh 转正为 firstboot.sh, 删掉 hook.sh/expandtoexfat.sh)
#   2. 扩容跑完 (或超时) 后再执行 hook: 机型检测 / quirks / 私编包 /
#      SDL 旋转库 / 语言。放在扩容之后, 私编包的 BIOS 才能直接写进 /roms。
# 超时被杀的扩容不会挡住 hook: timeout 返回后继续执行, hook.sh 仍在就跑它,
# 已被转正则运行转正后的 firstboot.sh (内容就是 hook)。
#
# 语言不在机身上选择: PC 端 dtbselector 选中文会写 /boot/.cn (zh-CN),
# 选 English 会删掉它, hook 读这个标记写 ES/RetroArch/PPSSPP。
timeout 600 /boot/expandtoexfat.sh > /dev/tty1 2>&1 || true

if [ -x /boot/hook.sh ]; then
  /boot/hook.sh
elif grep -q "apply_private_chinese" /boot/firstboot.sh 2>/dev/null; then
  # expand 已把 hook 转正为 firstboot.sh: 运行转正后的版本
  /boot/firstboot.sh
else
  echo "[firstboot] hook missing after expand, skipping" >&2
fi

# psvita (Vita3K-Plus): game dir + Vita3k data/firmware dirs must be created
# AFTER expandtoexfat.sh (first boot mkfs.exfat would wipe them).
mkdir -p /roms/psvita /roms/psvita/Vita3k /roms/psvita/Vita3k/firmware 2>/dev/null || true
chown ark:ark /roms/psvita /roms/psvita/Vita3k /roms/psvita/Vita3k/firmware 2>/dev/null || true
