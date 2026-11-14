#!/bin/bash
# ============================================================
# dArkOS 开机钩子 (arkos4clone clone.sh 结构的 rk3562 实现)
#
# 原版机制 (对齐 ~/arkos4clone/boot/dArkOS/clone.sh):
#   * 首启: expandtoexfat.sh 调本脚本 → 写 .console/hostname → 全量 quirks
#     应用 → 本脚本在首启后成为 /boot/firstboot.sh, firstboot.service
#     **不关闭** → 每次开机都执行
#   * 每次开机: console_detect -b (读 extlinux/boot.ini 的 FDT → 设备名)
#     与 /boot/.console 比较 —— **DTB 变化检测**; dtbselector 换 FDT 后
#     -b 返回新设备名 != .console 旧值 → 触发全量 quirks 应用
#     (SDL2/SDL3 旋转库替换 + RA/ES/PPSSPP 输入配置)
#   * runtime device-tree model 与 .console 不一致同样触发
# 日志: /boot/hook_log.txt
# ============================================================

QUIRKS_DIR="/home/ark/.quirks"
CONSOLE_FILE="/boot/.console"
CONSOLE_DETECT="/usr/local/bin/console_detect"
LOG_FILE="/boot/hook_log.txt"

if [[ $EUID -ne 0 ]]; then
  echo "[hook.sh] 需要 root: sudo $0"
  exit 1
fi

: > "$LOG_FILE" 2>/dev/null || true
msg()  { echo "[hook.sh] $*" | tee -a "$LOG_FILE" >/dev/null; echo "[hook.sh] $*"; sync "$LOG_FILE" 2>/dev/null || sync; }
warn() { echo "[hook.sh][WARN] $*" | tee -a "$LOG_FILE" >&2; sync "$LOG_FILE" 2>/dev/null || sync; }

# ==================== 设备检测 ====================
DEVICE_NAME=""
SCREEN_WIDTH=640
SCREEN_HEIGHT=480
JOYSTICK_COUNT=2
HOTKEY_TYPE="happy5"
SCREEN_ROTATION=0
LED_TYPE="unsupported"

SDL2_VERSION="libSDL2-2.0.so.0.3200.10"
SDL3_VERSION="libSDL3.so.0.4.16"

detect_device() {
  if [[ -x "$CONSOLE_DETECT" ]]; then
    eval "$("$CONSOLE_DETECT" -s)"
    msg "Device: $DEVICE_NAME, ${SCREEN_WIDTH}x${SCREEN_HEIGHT}, joy=$JOYSTICK_COUNT, hotkey=$HOTKEY_TYPE, rot=$SCREEN_ROTATION, led=$LED_TYPE"
  else
    warn "console_detect not found, using defaults"
    DEVICE_NAME="r36s"
  fi
}

get_console_label() {
  tr -d '\r\n' < "$CONSOLE_FILE" 2>/dev/null || true
}

# ==================== 工具函数 ====================
cp_if_exists() {
  local src="$1" dst="$2" isfile="${3:-no}"
  [[ -e "$src" ]] || { warn "Source not found: $src"; return 1; }
  if [[ "$isfile" == "yes" ]]; then
    mkdir -p "$(dirname "$dst")"
    rm -f "$dst" 2>/dev/null || true
    cp -L "$src" "$dst" 2>/dev/null || install -m 0755 -D "$src" "$dst"
    chmod 0755 "$dst" 2>/dev/null || true
  else
    mkdir -p "$dst"
    cp -a "$src" "$dst/"
    chmod -R 0755 "$dst" 2>/dev/null || true
  fi
  chown -R 1000:1000 "$dst" 2>/dev/null || true
  msg "Copied: $src -> $dst"
}

set_hostname() {
  local dev="$1" changed="no"
  [ -n "$dev" ] || return 0

  if [ "$(cat /etc/hostname 2>/dev/null)" != "$dev" ]; then
    echo "$dev" > /etc/hostname 2>/dev/null && changed="yes"
  fi

  # Keep exactly one 127.0.1.1 line for this device. A stale line (e.g.
  # "ngp45ht" after switching to ais) makes sudo fail with
  # "unable to resolve host".
  if ! grep -qxE "127\.0\.1\.1[[:space:]]+$dev([[:space:]]|$)" /etc/hosts 2>/dev/null; then
    sed -i -E '/^[[:space:]]*127\.0\.1\.1[[:space:]]/d' /etc/hosts 2>/dev/null || true
    echo "127.0.1.1    $dev" >> /etc/hosts 2>/dev/null || true
    changed="yes"
  fi

  # sudo/PAM resolves the *running* hostname, so update the kernel name too.
  if [ "$(hostname 2>/dev/null)" != "$dev" ]; then
    echo "$dev" > /proc/sys/kernel/hostname 2>/dev/null || true
    changed="yes"
  fi

  [ "$changed" = "yes" ] && msg "Hostname -> $dev"
}

# ==================== 配置应用 ====================
# 热键按钮: MODE(Guide) = 10, SELECT(Back) = 8; 其它机型保持 cfg 原值
apply_ra_hotkey() {
  local btn=""
  case "${HOTKEY_TYPE:-}" in
    mode)   btn="10" ;;
    select) btn="8"  ;;
    *)      return 0 ;;
  esac

  local f
  for f in "/home/ark/.config/retroarch/retroarch.cfg" \
           "/home/ark/.config/retroarch32/retroarch.cfg"; do
    [[ -f "$f" ]] || continue
    if grep -qE '^input_enable_hotkey_btn[[:space:]]*=' "$f"; then
      sed -i -E "s|^input_enable_hotkey_btn[[:space:]]*=.*|input_enable_hotkey_btn = \"$btn\"|" "$f"
    else
      printf '\ninput_enable_hotkey_btn = "%s"\n' "$btn" >> "$f"
    fi
    chown 1000:1000 "$f" 2>/dev/null || true
  done
  msg "RetroArch hotkey: $HOTKEY_TYPE -> btn $btn"
}

# ogage 全局热键: 与 arkos4clone 一致, 按机型只写一个 HOTKEY,
# 不再同时挂 HAPPY1/SELECT/MODE 三个候选 (会误触)
apply_ogage_hotkey() {
  local btn f=/home/ark/ogage.conf changed="no"
  case "${HOTKEY_TYPE:-}" in
    mode)   btn="BTN_MODE" ;;
    select) btn="BTN_SELECT" ;;
    happy5) btn="BTN_TRIGGER_HAPPY5" ;;
    *)      return 0 ;;
  esac
  [ -f "$f" ] || return 0

  if ! grep -q "^HOTKEY=$btn$" "$f"; then
    sed -i -E '/^HOTKEY[0-9]?=/d' "$f" 2>/dev/null || true
    sed -i "1i HOTKEY=$btn" "$f" 2>/dev/null || true
    changed="yes"
  fi

  # 风扇切换 (热键+START): console_detect 报告有 pwm-fan 的机型才启用
  local fan="no"
  [[ "${FAN:-no}" == "yes" ]] && fan="yes"
  if [ "$fan" = "yes" ]; then
    grep -q '^FAN_TOGGLE=yes$' "$f" || {
      sed -i '/^FAN_TOGGLE=/d' "$f" 2>/dev/null || true
      sed -i "1i FAN_TOGGLE=yes" "$f" 2>/dev/null || true
      changed="yes"
    }
  elif grep -q '^FAN_TOGGLE=' "$f"; then
    sed -i '/^FAN_TOGGLE=/d' "$f" 2>/dev/null || true
    changed="yes"
  fi

  chown 1000:1000 "$f" 2>/dev/null || true
  [ "$changed" = "yes" ] && systemctl is-active --quiet ogage && systemctl restart ogage
  msg "ogage hotkey: $btn, fan-toggle: $fan"
}

apply_input() {
  msg "apply_input"
  cp_if_exists "$QUIRKS_DIR/retroarch64.cfg" "/home/ark/.config/retroarch/retroarch.cfg" "yes" || true
  cp_if_exists "$QUIRKS_DIR/retroarch32.cfg" "/home/ark/.config/retroarch32/retroarch.cfg" "yes" || true
  apply_ra_hotkey
  cp_if_exists "$QUIRKS_DIR/es_input.cfg" "/etc/emulationstation/es_input.cfg" "yes" || true
}


# ==================== 国际化 ====================
# PC 端 dtb 选择器选择中文时写 /boot/.cn; 开机应用一次后删除 (同 arkos4clone)
apply_localization() {
  local lang="$1" es_lang ra_lang ppsspp_lang ppsspp_from
  case "$lang" in
    cn) es_lang="zh-CN"; ra_lang="12"; ppsspp_lang="zh_CN"; ppsspp_from="en_US" ;;
    en) es_lang="en";    ra_lang="0";  ppsspp_lang="en_US"; ppsspp_from="zh_CN" ;;
    *)  return 0 ;;
  esac
  msg "Applying $lang localization"

  # EmulationStation
  local es_cfg="/home/ark/.emulationstation/es_settings.cfg"
  if [ ! -f "$es_cfg" ]; then
    mkdir -p "$(dirname "$es_cfg")"
    printf '<?xml version="1.0"?>\n' > "$es_cfg"
  fi
  if [ -f "$es_cfg" ]; then
    if grep -q '<string name="Language"' "$es_cfg"; then
      sed -i "s|<string name=\"Language\" value=\"[^\"]*\"|<string name=\"Language\" value=\"$es_lang\"|" "$es_cfg" 2>/dev/null || true
    else
      printf '<string name="Language" value="%s" />\n' "$es_lang" >> "$es_cfg"
    fi
    chown 1000:1000 "$es_cfg" 2>/dev/null || true
    if grep -q "<string name=\"Language\" value=\"$es_lang\"" "$es_cfg"; then
      msg "ES language: $es_lang"
    else
      warn "ES language write failed: $es_cfg"
    fi
  fi

  # 其它脚本/启动器用这个标记判断中文
  mkdir -p /home/ark/.config
  if [ "$lang" = "cn" ]; then
    touch /home/ark/.config/.cn
    chown 1000:1000 /home/ark/.config/.cn 2>/dev/null || true
  else
    rm -f /home/ark/.config/.cn
  fi

  # RetroArch / RetroArch32 (user_language: 12 = 简体中文)
  local cfg
  for cfg in /home/ark/.config/retroarch/retroarch.cfg \
             /home/ark/.config/retroarch32/retroarch.cfg; do
    [ -f "$cfg" ] || continue
    if grep -q '^user_language[[:space:]]*=' "$cfg"; then
      sed -i -E "s|^user_language[[:space:]]*=.*|user_language = \"$ra_lang\"|" "$cfg" 2>/dev/null || true
    else
      printf '\nuser_language = "%s"\n' "$ra_lang" >> "$cfg"
    fi
    chown 1000:1000 "$cfg" 2>/dev/null || true
  done

  # PPSSPP (与 arkos4clone 一致: 只替换语言那一行)
  local dir ini
  for dir in /opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM \
             /roms/psp/ppsspp/PSP/SYSTEM \
             /roms2/psp/ppsspp/PSP/SYSTEM; do
    [ -d "$dir" ] || continue
    for ini in ppsspp.ini ppsspp.ini.go ppsspp.ini.sdl; do
      [ -f "$dir/$ini" ] || continue
      sed -i "s/Language = $ppsspp_from/Language = $ppsspp_lang/g" "$dir/$ini" 2>/dev/null || true
    done
  done
  msg "Localization: ES=$es_lang RA=$ra_lang PPSSPP=$ppsspp_lang"
}

# 私编中文 duckstation-mini (不随镜像发布, CC BY-NC-ND): dtbselector 选中文
# (/boot/.cn 存在) 且 boot 分区放了 duckstation-mini-zh-private.tar.xz 时,
# 解到 /opt 覆盖安装, standalone-duckstation 启动器会自动优先用它;
# 把压缩包从 boot 分区删掉(或选 English)下次开机就回官方版.
DS_PRIV_DIR=/opt/duckstation-mini-zh-private
DS_PRIV_STAMP="$DS_PRIV_DIR/.archive"
apply_private_duckstation() {
  local t="" stamp
  if [ ! -f /boot/.cn ]; then
    # 只回收我们自己装的 (有 stamp), 不动手动部署的目录
    if [ -f "$DS_PRIV_STAMP" ]; then
      rm -rf "$DS_PRIV_DIR"
      msg "Private duckstation-mini-zh removed (language not zh-CN)"
    fi
    return 0
  fi
  for t in /boot/duckstation-mini-zh-private.tar.xz \
           /boot/duckstation-mini-zh-private.tar.gz \
           /boot/duckstation-mini-zh-private.tar; do
    [ -f "$t" ] && break
    t=""
  done
  [ -n "$t" ] || return 0
  stamp="$(basename "$t")-$(stat -c %s "$t" 2>/dev/null)"
  [ "$(cat "$DS_PRIV_STAMP" 2>/dev/null)" = "$stamp" ] && return 0
  msg "Installing private duckstation-mini-zh from $t"
  rm -rf "$DS_PRIV_DIR" "$DS_PRIV_DIR.tmp"
  mkdir -p "$DS_PRIV_DIR.tmp"
  if ! tar -xf "$t" -C "$DS_PRIV_DIR.tmp"; then
    warn "extract failed: $t (需要 /opt 有足够空间)"
    rm -rf "$DS_PRIV_DIR.tmp"
    return 1
  fi
  if [ -d "$DS_PRIV_DIR.tmp/duckstation-mini-zh-private" ]; then
    mv "$DS_PRIV_DIR.tmp/duckstation-mini-zh-private" "$DS_PRIV_DIR"
  else
    mv "$DS_PRIV_DIR.tmp" "$DS_PRIV_DIR"
  fi
  rm -rf "$DS_PRIV_DIR.tmp"
  chmod -R 777 "$DS_PRIV_DIR" 2>/dev/null || true
  printf '%s\n' "$stamp" > "$DS_PRIV_STAMP"
  # 一次性输入: 装好后删掉 boot 分区上的压缩包, 不再长期占用 32MB
  rm -f "$t" 2>/dev/null && msg "Removed $t after install"
  sync
  msg "Private duckstation-mini-zh installed: $stamp"
}

apply_joy_conf() {
  msg "apply_joy_conf: JOYSTICK_COUNT=$JOYSTICK_COUNT"
  local joy_type="none"
  [[ "$JOYSTICK_COUNT" == "2" ]] && joy_type="dual"
  for roms_dir in "/roms/psp" "/roms2/psp" "/opt/ppsspp/backupforromsfolder"; do
    [[ -d "$roms_dir" ]] || continue
    local target="$roms_dir/ppsspp/PSP/SYSTEM"
    cp_if_exists "$QUIRKS_DIR/${joy_type}Joy/controls.ini"   "$target/controls.ini" "yes" || true
    cp_if_exists "$QUIRKS_DIR/${joy_type}Joy/ppsspp.ini"     "$target/ppsspp.ini"   "yes" || true
    cp_if_exists "$QUIRKS_DIR/${joy_type}Joy/ppsspp.ini.sdl" "$target/ppsspp.ini.sdl" "yes" || true
  done
}

apply_es_setting() {
  msg "apply_es_setting"
  local target="/home/ark/.emulationstation/es_settings.cfg"
  local per_device="$QUIRKS_DIR/${DEVICE_NAME}/es_settings.cfg"
  local src="$QUIRKS_DIR/es_settings.cfg"

  # 机型专属配置优先
  [[ -f "$per_device" ]] && src="$per_device"

  # 覆盖前保留一份原始配置 (只存一次)
  [[ -f "$target" && ! -f "$target.orig" ]] && cp -f "$target" "$target.orig" 2>/dev/null || true

  if [[ -f "$src" ]]; then
    cp_if_exists "$src" "$target" "yes" || true

    # 语言跟随 /home/ark/.config/.cn 标记: 中文 -> zh-CN, 否则 en
    if [[ -f "$target" ]]; then
      if [[ -f /home/ark/.config/.cn ]]; then
        sed -i 's|name="Language" value="[^"]*"|name="Language" value="zh-CN"|' "$target" 2>/dev/null || true
      else
        sed -i 's|name="Language" value="[^"]*"|name="Language" value="en"|' "$target" 2>/dev/null || true
      fi
    fi
  fi
}

apply_sdl_rotation() {
  local angle="$1"
  local suffix="norotate"
  [[ "$angle" != "0" ]] && suffix="rotate${angle}"
  msg "SDL rotation: $suffix"

  local -a dirs=(
    "/usr/lib/aarch64-linux-gnu:$QUIRKS_DIR/rotate/sdl2/64"
    "/usr/lib/arm-linux-gnueabihf:$QUIRKS_DIR/rotate/sdl2/32"
    "/usr/lib/aarch64-linux-gnu:$QUIRKS_DIR/rotate/sdl3/64"
    "/usr/lib/arm-linux-gnueabihf:$QUIRKS_DIR/rotate/sdl3/32"
  )
  local entry dir srcdir src target base f
  for entry in "${dirs[@]}"; do
    IFS=: read -r dir srcdir <<< "$entry"   # 只读两段
    [[ -d "$dir" ]] || continue
    src=""
    for f in "$srcdir"/*."$suffix"; do
      [[ -f "$f" ]] && { src="$f"; break; }
    done
    if [[ -z "$src" ]]; then
      warn "variant missing: $srcdir/*.$suffix ($dir keeps current)"
      continue
    fi
    base="$(basename "$src")"
    base="${base%.$suffix}"                 # 去掉 .norotate / .rotate90
    target="$dir/$base"
    rm -f "$target"
    if cp "$src" "$target"; then
      msg "installed $suffix -> $target"
    else
      warn "copy failed: $src"
    fi
  done

  msg "rebuilding SDL soname links"
  local d
  for d in /usr/lib/aarch64-linux-gnu /usr/lib/arm-linux-gnueabihf; do
    [[ -d "$d" ]] || continue
    ln -sfn "$SDL2_VERSION" "$d/libSDL2-2.0.so.0"
    ln -sfn "libSDL2-2.0.so.0" "$d/libSDL2-2.0.so"
    ln -sfn "libSDL2-2.0.so" "$d/libSDL2.so"
    ln -sfn "$SDL3_VERSION" "$d/libSDL3.so.0"
    ln -sfn "libSDL3.so.0" "$d/libSDL3.so"
  done
}

apply_all_quirks() {
  msg "Applying quirks for: $DEVICE_NAME"
  [[ -d "$QUIRKS_DIR" ]] || { warn "QUIRKS_DIR missing: $QUIRKS_DIR"; return 0; }
  apply_input
  apply_es_setting
  apply_joy_conf
  apply_sdl_rotation "$SCREEN_ROTATION"
}

# ==================== 附加处理 ====================
# WiFi 驱动加载 (取代 wifi-driver-load.service, 每次开机执行, modprobe 幂等)。
# 硬件矩阵:
#   SDIO: rg52mini / rg43h / rg43v (同型号两个硬件版本: RK915 或 AIC8800),
#         ais (AIC8800D80)
#   USB : ngp45ht (AIC8800DC), xf55h (ZTop ZT9101)
# 判别方式: 只有 SDIO 机型有 wireless-wlan 节点且 status=okay;
#   ngp45ht 该节点为 disabled, xf55h 没有该节点 → 两者都走 USB。
# 为什么 SDIO 必须由 userspace 触发:
#   1) 芯片上电由驱动 init 完成 (rockchip_wifi_power), 未上电不会枚举,
#      udev 拿不到 SDIO modalias (自举死锁);
#   2) aic8800_bsp 与 USB loader 导出同名符号 (get_adap_test), 两套栈
#      不能同时存在, 必须按总线二选一;
#   3) rk915 只注册 platform alias, 没有可用的 SDIO modalias 自动加载。
# rk915 的 init 会真正 probe 芯片, 不匹配时返回错误并放下电源轨,
# 因此可以安全地 "先 rk915, 失败再 AIC SDIO"。
load_wifi_modules() {
  local st=""

  if [ -r /proc/device-tree/wireless-wlan/status ]; then
    st=$(tr -d '\0' < /proc/device-tree/wireless-wlan/status)
  fi

  if [ "$st" = "okay" ]; then
    if modprobe rk915 2>/dev/null; then
      msg "WiFi: rk915 (SDIO) loaded"
      return 0
    fi
    modprobe aic8800_bsp 2>/dev/null
    modprobe aic8800_fdrv 2>/dev/null
    msg "WiFi: aic8800 SDIO stack loaded"
    return 0
  fi

  # USB 机型: AIC 与 ZT9101 驱动互不冲突, 都注册, 由 USB ID 各自绑定;
  # 设备枚举晚到也会被已注册的 driver/udev 接住。
  if modprobe aic_load_fw_usb 2>/dev/null && modprobe aic8800_fdrv_usb 2>/dev/null; then
    msg "WiFi: aic8800 USB stack loaded"
  fi
  if modprobe zt9101_ztopmac_usb 2>/dev/null; then
    msg "WiFi: zt9101 USB loaded"
  fi
}

apply_fc_cache() {
  if [ ! -d /var/cache/fontconfig ] || ! ls /var/cache/fontconfig/* >/dev/null 2>&1; then
    fc-cache -f >/dev/null 2>&1 && msg "fontconfig cache rebuilt"
  fi
}

apply_duckstation_hotkeys() {
  local hk s block
  # 与 gamecontrollerdb 对应: mode=BTN_MODE(HOME)->Guide, select=Back,
  # happy5=BTN_TRIGGER_HAPPY5->Misc1 (该键在 rk3562 手柄上不存在, 别混用)
  case "$HOTKEY_TYPE" in
    select) hk="SDL-0/Back" ;;
    mode)   hk="SDL-0/Guide" ;;
    *)      hk="SDL-0/Misc1" ;;
  esac
  s="/home/ark/.local/share/duckstation/settings.ini"
  if [ ! -f "$s" ]; then
    mkdir -p "$(dirname "$s")"
    cp /opt/duckstation/settings.ini.template "$s" 2>/dev/null || return 0
  fi
  sed -i --follow-symlinks -E '/^(OpenPauseMenu|LoadSelectedSaveState|SaveSelectedSaveState|FastForward) =/d' "$s" 2>/dev/null || true
  block="OpenPauseMenu = $hk & SDL-0/X
LoadSelectedSaveState = $hk & SDL-0/LeftTrigger
SaveSelectedSaveState = $hk & SDL-0/RightTrigger
FastForward = $hk & SDL-0/LeftShoulder"
  if grep -q '^\[Hotkeys\]' "$s"; then
    awk -v b="$block" '{ print } /^\[Hotkeys\]/{ print b }' "$s" > "$s.tmp" && mv "$s.tmp" "$s"
  else
    printf '\n[Hotkeys]\n%s\n' "$block" >> "$s"
  fi
  chown 1000:1000 "$s" 2>/dev/null || true
  msg "DuckStation hotkeys: $hk + X/L2/R2/L1"
}

# ARMSX2 (PS2): OpenPauseMenu = 机型 hotkey + X (PCSX2.ini 的 [Hotkeys] 段;
# SDL 绑定名见 SDLInputSource.cpp, 本机 SDL 映射 x:b3 -> FaceWest)
apply_armsx2_hotkeys() {
  local hk f
  case "$HOTKEY_TYPE" in
    select) hk="SDL-0/Back" ;;
    mode)   hk="SDL-0/Guide" ;;
    *)      hk="SDL-0/Misc1" ;;
  esac
  local line="OpenPauseMenu = $hk & SDL-0/FaceWest"
  local b
  for b in /roms /roms2; do
    f="$b/ps2/armsx2/.config/ARMSX2/inis/PCSX2.ini"
    [ -f "$f" ] || continue
    sed -i -E '/^OpenPauseMenu[[:space:]]*=/d' "$f" 2>/dev/null || true
    if grep -q '^\[Hotkeys\]' "$f"; then
      awk -v l="$line" '{ print } /^\[Hotkeys\]/{ print l }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    else
      printf '\n[Hotkeys]\n%s\n' "$line" >> "$f"
    fi
    chown 1000:1000 "$f" 2>/dev/null || true
  done
  msg "ARMSX2 hotkey: $hk + X (OpenPauseMenu)"
}

# RetroArch udev 手柄的轴编号按"已存在的 ABS 轴"压缩, 不是 evdev 的 ABS 码:
#   rg52mini/rg43h/rg43v/ais/xf55h 有模拟扳机 (ABS_Z/ABS_RZ), 轴序为
#     X=0 Y=1 Z=2 RX=3 RY=4 RZ=5
#   ngp45ht 的 L2/R2 是数字键, 只有 ABS_X/Y/RX/RY, 轴序压缩为
#     X=0 Y=1 RX=2 RY=3
# autoconfig 里写死的 r_x=3/r_y=4 在 ngp45ht 上会把右摇杆的竖直轴当成 X、
# 水平轴落到不存在的轴 4 (光标只能左右跟着上下动, 左右完全没反应);
# l2_axis=2 还会把右摇杆水平轴当 L2. 按 DT 是否有 l2-abs 区分两种情况.
apply_retroarch_axes() {
  local analog_triggers="yes"
  if [ -r /proc/device-tree/play_joystick/io-channel-names ]; then
    tr -d '\0' < /proc/device-tree/play_joystick/io-channel-names \
      | grep -q 'l2-abs' || analog_triggers="no"
  fi

  local rx_minus="-3" rx_plus="+3" ry_minus="-4" ry_plus="+4"
  local l2_axis="+2" r2_axis="+5" l2_btn="nul" r2_btn="nul"
  if [ "$analog_triggers" = "no" ]; then
    rx_minus="-2"; rx_plus="+2"; ry_minus="-3"; ry_plus="+3"
    l2_axis="nul"; r2_axis="nul"; l2_btn="6"; r2_btn="7"
  fi

  local cfg key val entry
  for cfg in \
      /home/ark/.config/retroarch/retroarch.cfg \
      /home/ark/.config/retroarch32/retroarch.cfg \
      /home/ark/.config/retroarch/autoconfig/udev/rk3562-joystick.cfg \
      /home/ark/.config/retroarch32/autoconfig/udev/rk3562-joystick.cfg; do
    [ -f "$cfg" ] || continue
    for entry in \
        "input_player1_r_x_minus_axis:$rx_minus" \
        "input_player1_r_x_plus_axis:$rx_plus" \
        "input_player1_r_y_minus_axis:$ry_minus" \
        "input_player1_r_y_plus_axis:$ry_plus" \
        "input_player1_l2_axis:$l2_axis" \
        "input_player1_r2_axis:$r2_axis" \
        "input_player1_l2_btn:$l2_btn" \
        "input_player1_r2_btn:$r2_btn"; do
      key="${entry%%:*}"
      val="${entry#*:}"
      if grep -q "^$key *=" "$cfg" 2>/dev/null; then
        sed -i -E "s|^$key *=.*|$key = \"$val\"|" "$cfg"
      else
        printf '%s = "%s"\n' "$key" "$val" >> "$cfg"
      fi
    done
    chown 1000:1000 "$cfg" 2>/dev/null || true
  done

  msg "RetroArch sticks: analog_triggers=$analog_triggers r_x=$rx_minus/$rx_plus r_y=$ry_minus/$ry_plus"
}

# ==================== 主流程 ====================
QUIRKS_STAMP="/boot/.quirks_applied"

write_quirks_stamp() {
  echo "$DEVICE_NAME:rot$SCREEN_ROTATION" > "$QUIRKS_STAMP" 2>/dev/null || true
}

main() {
  local first_boot="no"
  [[ ! -f "$CONSOLE_FILE" ]] && first_boot="yes"

  # boot.ini/extlinux.conf 里的 DTB → 设备名 (DTB 变化检测的"新值")
  local bootini_device=""
  if [[ -x "$CONSOLE_DETECT" ]]; then
    bootini_device="$("$CONSOLE_DETECT" -b 2>/dev/null || true)"
  fi

  detect_device

  local cur_val; cur_val="$(get_console_label)"

  # .console 不能作为"已应用 quirks"依据: dtbselector 在 PC 侧选机时就预写
  # .console (main.go:117), 首启时它已存在且与机型一致 → 旧逻辑跳过全部
  # quirks, SDL 永不替换。独立标记记录"已为哪个机型+旋转角应用过"。
  local quirks_pending="yes"
  if [[ -f "$QUIRKS_STAMP" && "$(cat "$QUIRKS_STAMP" 2>/dev/null)" == "$DEVICE_NAME:rot$SCREEN_ROTATION" ]]; then
    quirks_pending="no"
  fi

  local dtb_changed="no"
  if [[ -n "$bootini_device" && "$cur_val" != "$bootini_device" ]]; then
    dtb_changed="yes"
    msg "DTB changed: .console=$cur_val, extlinux=$bootini_device"
  fi

  if [[ "$first_boot" == "yes" || "$quirks_pending" == "yes" ]]; then
    printf '\033c'
    echo "==================================="
    echo "   dArkOS3562 first boot setup"
    echo "==================================="
    sleep 2
    echo "$DEVICE_NAME" | tee "$CONSOLE_FILE" >/dev/null
    set_hostname "$DEVICE_NAME"
    msg "First boot (or quirks pending), device=$DEVICE_NAME"
    apply_all_quirks
    apply_fc_cache
    write_quirks_stamp
    msg "Running depmod -a"
    depmod -a 2>/dev/null || true
  elif [[ "$dtb_changed" == "yes" || "$cur_val" != "$DEVICE_NAME" ]]; then
    local old_device="$cur_val" new_device
    if [[ "$dtb_changed" == "yes" ]]; then
      new_device="$bootini_device"
      msg "DTB changed: $old_device -> $new_device"
    else
      new_device="$DEVICE_NAME"
      msg "Console changed: $old_device -> $new_device"
    fi
    echo "$new_device" | tee "$CONSOLE_FILE" >/dev/null
    set_hostname "$new_device"
    # 设备变了: 重新检测参数 (旋转角度等) 后全量应用
    detect_device
    (
      printf '\033c'
      echo "==================================="
      echo "   dArkOS3562 device changed"
      echo "==================================="
      echo; echo "old: $old_device"; echo "new: $new_device"
      apply_all_quirks
      sleep 5
    ) > /dev/tty1 2>&1
    write_quirks_stamp
    msg "Running depmod -a"
    depmod -a 2>/dev/null || true
  else
    msg "Console unchanged: $cur_val"
    # .console/extlinux 已对，但 /etc/hostname 或 /etc/hosts 可能仍是
    # 旧机型 (PC 端 dtbselector 切换后首次开机). 这里保持三者一致.
    set_hostname "$DEVICE_NAME"
  fi

  # 语言只认 PC 端 dtbselector 写的 /boot/.cn (选中文=存在, 选 English=删除),
  # 机身不再弹框选择; 每次开机把 ES/RA/PPSSPP 同步到该选择.
  # ES 本构建没有语言菜单, 设置只能写进 es_settings.cfg.
  local es_lang_cur
  es_lang_cur=$(sed -n 's|.*<string name="Language" value="\([^"]*\)".*|\1|p' \
    /home/ark/.emulationstation/es_settings.cfg 2>/dev/null | head -n1)
  if [ -f /boot/.cn ]; then
    [ "$es_lang_cur" = "zh-CN" ] || apply_localization cn
  elif [ "$es_lang_cur" = "zh-CN" ]; then
    apply_localization en
  fi

  apply_private_duckstation

  # 已扩容的卡上不应再执行首启扩容: 清掉残留脚本, 避免换机型时再次进入
  if [ -f /boot/expandtoexfat.sh ] && [ ! -f /boot/fstab.exfat ]; then
    for pdev in /dev/mmcblk0p5 /dev/mmcblk1p5; do
      if [ -b "$pdev" ] && lsblk -no FSTYPE "$pdev" 2>/dev/null | grep -qi exfat; then
        if [ -f /boot/hook.sh ] && grep -q expandtoexfat /boot/firstboot.sh 2>/dev/null; then
          cp -f /boot/hook.sh /boot/firstboot.sh
          rm -f /boot/hook.sh
        fi
        rm -f /boot/expandtoexfat.sh
        msg "expandtoexfat.sh removed (ROM partition already exfat)"
        break
      fi
    done
  fi

  # DuckStation 热键按机型热键类型生成 (happy5=FN/Misc1, select=Back)
  apply_duckstation_hotkeys

  # ARMSX2 (PS2) 暂停菜单: 机型热键 + X
  apply_armsx2_hotkeys

  # 全局按键守护 ogage: 按机型只写一个热键 (ArkOS 同款)
  apply_ogage_hotkey

  # 右摇杆/扳机轴索引按机型 (是否有模拟扳机) 修正, 每次开机都写
  apply_retroarch_axes

  # RetroArch 的 DuckStation 核心需要 BIOS 搜索路径, 否则核心无法启动
  ROPT=/home/ark/.config/retroarch/retroarch-core-options.cfg
  if [ -d /home/ark/.config/retroarch ] && ! grep -q '^duckstation_BIOS.SearchDirectory' "$ROPT" 2>/dev/null; then
    echo 'duckstation_BIOS.SearchDirectory = "/roms/bios"' >> "$ROPT"
  fi

  # 每次开机都做的轻量项
  # 亮度持久化: ES 只写 sysfs 不保存, brightness-watch 服务负责落盘,
  # 这里开机恢复; 没有记录时不动背光 (保持内核/dtb 默认)
  BL_CFG="/home/ark/.config/brightness.level"
  BL_SYS="/sys/class/backlight/backlight/brightness"
  if [ -w "$BL_SYS" ] && [ -f "$BL_CFG" ]; then
    bl=$(cat "$BL_CFG" 2>/dev/null || true)
    if [[ "$bl" =~ ^[0-9]+$ ]] && [ "$bl" -le 255 ]; then
      echo "$bl" > "$BL_SYS" 2>/dev/null && msg "Brightness: $bl"
    fi
  fi
  # 色温 + gamma: 内核 VOP2 参数在时把保存值写回 (游戏/Kodi 也生效);
  # 没有内核支持时 ES 启动会调用 colortemp -apply 重放
  CT_SYS="/sys/module/rockchipdrm/parameters/colortemp"
  CT_CONF="/home/ark/.config/colortemp.conf"
  if [ -w "$CT_SYS" ] && [ -f "$CT_CONF" ]; then
    ct=$(awk '$1=="kelvin" { print $2; exit }' "$CT_CONF" 2>/dev/null)
    if [[ "$ct" =~ ^[0-9]+$ ]] && [ "$ct" -le 9000 ]; then
      echo "$ct" > "$CT_SYS" 2>/dev/null && msg "Color temperature: ${ct}K"
    fi
    read -r _ gr gg gb < <(awk '$1=="gamma" { print $2, $3, $4; exit }' "$CT_CONF" 2>/dev/null) || true
    for ch in r g b; do
      eval "val=\$$ch"
      [[ "$val" =~ ^[0-9]*\.?[0-9]+$ ]] || continue
      pm=$(awk -v v="$val" 'BEGIN { printf "%d", v * 1000 + 0.5 }')
      if [ "$pm" -ge 100 ] && [ "$pm" -le 2000 ]; then
        echo "$pm" > "${CT_SYS}_$ch" 2>/dev/null || true
      fi
    done
    msg "Color gamma restored: ${gr:-1} ${gg:-1} ${gb:-1}"
  fi
  # gptokeyb (onscripter 的菜单导航) 需要写 uinput
  chmod 666 /dev/uinput 2>/dev/null || true
  mkdir -p /roms/3ds 2>/dev/null || true
  [ -d /roms2 ] && mkdir -p /roms2/3ds 2>/dev/null || true
  load_wifi_modules
  # 清 RK817 POWER_EN_SAVE0/1，避免关机时 reboot-notifier 把 POWER_EN
  # 恢复回去导致关机后自启；与 ROCKNIX 的 not-save-power-en 等价.
  /usr/local/bin/rk817-fix-shutdown.sh >/dev/null 2>&1 || true
  /usr/local/bin/rk817-audio-path.sh 2>/dev/null || true
  apply_fc_cache
  ldconfig 2>/dev/null && msg "ldconfig refreshed"
  msg "done"
}

main "$@"
