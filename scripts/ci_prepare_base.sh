#!/bin/bash
# ============================================================
# ci_prepare_base.sh — CI 用: 下载并解压基线镜像
#
# 用法: ci_prepare_base.sh <url> [目标文件名]
#   url 支持的形态:
#     *.img                   直接下载
#     *.img.xz / *.xz         下载后 unxz
#     *.7z / *.7z.001         7z 单卷或多分卷 (自动下载 .001/.002/...)
#   目标文件名默认 dArkOS_rg52mini_trixie_06242026.img (sync_image.sh 约定)
#
# 说明: 基线镜像不进仓库, 由 CI 从 Release/对象存储下载。GitHub Release
# 单文件上限 2GB, 所以基线通常以 7z 分卷 + xz 发布。
# ============================================================
set -euo pipefail

URL="${1:?usage: $0 <url> [basename.img]}"
TARGET="${2:-dArkOS_rg52mini_trixie_06242026.img}"
WORK="${CI_WORK_DIR:-$PWD}"

mkdir -p "$WORK"
cd "$WORK"

log() { printf '[ci-base] %s\n' "$*"; }

download() { wget -q --show-progress --progress=bar:force:noscroll "$1"; }

if [[ "$URL" == *.7z.001 ]]; then
  log "多分卷下载: ${URL}"
  part=0
  while :; do
    suffix=$(printf "%03d" "$part")
    u="${URL%.001}.${suffix}"
    if ! download "$u"; then
      if [[ "$part" -eq 0 ]]; then log "ERROR: 首卷下载失败: $u" >&2; exit 1; fi
      log "分卷结束 (已下载 $part 卷)"
      break
    fi
    part=$((part + 1))
  done
  first=$(ls ./*.7z.001 | head -1)
  log "解压 7z 分卷: $first"
  7z x "$first" -o. -y >/dev/null
  rm -f ./*.7z.[0-9][0-9][0-9]
elif [[ "$URL" == *.7z ]]; then
  download "$URL"
  f=$(basename "$URL")
  log "解压 7z: $f"
  7z x "$f" -o. -y >/dev/null
  rm -f "$f"
else
  download "$URL"
fi

# xz 解压 (基线通常是 .img.xz)
for f in *.xz; do
  [[ -f "$f" ]] || continue
  log "解压 xz: $f"
  unxz -T0 "$f"
done

img=$(ls -S -- *.img 2>/dev/null | head -1 || true)
if [[ -z "$img" ]]; then
  log "ERROR: 未找到 .img 镜像" >&2
  exit 1
fi

if [[ "$img" != "$TARGET" ]]; then
  log "重命名: $img -> $TARGET"
  mv -f -- "$img" "$TARGET"
fi

size=$(stat -c%s "$TARGET")
[[ "$size" -gt $((1024*1024*1024)) ]] || { log "ERROR: 镜像太小 ($size bytes)" >&2; exit 1; }
log "完成: $TARGET ($(numfmt --to=iec "$size"))"
