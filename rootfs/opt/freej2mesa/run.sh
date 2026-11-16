#!/bin/bash
# FreeJ2ME-Mesa standalone: 系统 JDK, 二进制放这里, 由 freej2me.sh 调用
export JAVA_TOOL_OPTIONS='-Xverify:none -Djava.util.prefs.systemRoot=./.java -Djava.util.prefs.userRoot=./.java/.userPrefs -Djava.library.path=./'
cd "$(dirname "$0")" || exit 1

GAME_PATH="$1"
WIDTH=320
HEIGHT=240
if [ -n "$GAME_PATH" ]; then
  RESOLUTION=$(echo "$GAME_PATH" | grep -oP '[0-9]{2,4}x[0-9]{2,4}' | head -1)
  if [ -n "$RESOLUTION" ]; then
    WIDTH="${RESOLUTION%x*}"
    HEIGHT="${RESOLUTION#*x}"
  fi
fi
[ -n "$2" ] && [ -n "$3" ] && WIDTH="$2" && HEIGHT="$3"

# 空格/方括号等会让 freej2me 构造 jar: URL 失败 (Illegal character in opaque part),
# 统一复制成安全文件名再加载
SAFE="/tmp/freej2me-game.jar"
cp -f "$GAME_PATH" "$SAFE" || exit 1
GAME_PATH="$SAFE"

java -jar freej2me-sdl.jar "$GAME_PATH" "$WIDTH" "$HEIGHT" 100
RC=$?
rm -f "$SAFE"
exit $RC
