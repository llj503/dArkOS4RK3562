#!/bin/bash
# Azahar (3DS) 专用启动: RetroArch 的 gl 驱动下 core 会 shader 失败崩溃,
# 必须走 Vulkan; 且 Mali 官方 blob 没有 KHR_display, 用自编 malisx2.
# savefiles_in_content_dir=false: 存档/用户目录固定为 savefile_directory/Azahar,
# 否则 core 会把 user dir 指到游戏目录, 字库和 DLC 每次都要按目录重装.
export VK_ICD_FILENAMES=/opt/malisx2/malisx2.json
CFG=/tmp/azahar-video.cfg
printf 'video_driver = "vulkan"\nsavefiles_in_content_dir = "false"\n' > "$CFG"
exec /usr/local/bin/retroarch -c /home/ark/.config/retroarch/retroarch.cfg \
  --appendconfig "$CFG" \
  -L /home/ark/.config/retroarch/cores/azahar_libretro.so "$@"
