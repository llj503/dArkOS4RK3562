#!/bin/bash
# hakuX (Xbox) 专用启动: 核心用 Vulkan hw_render 渲染, RetroArch 的默认
# gl 驱动会让它拒绝启动, 强制本次使用 vulkan; 不覆盖系统默认 ICD
# (rk_vk.json / libmali, Vulkan 1.3 满足核心要求)。
CFG=/tmp/hakux-video.cfg
printf 'video_driver = "vulkan"\n' > "$CFG"
exec /usr/local/bin/retroarch -c /home/ark/.config/retroarch/retroarch.cfg \
  --appendconfig "$CFG" \
  -L /home/ark/.config/retroarch/cores/hakux-lr_libretro.so "$@"
