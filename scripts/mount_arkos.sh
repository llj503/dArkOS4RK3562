#!/usr/bin/env bash
set -euo pipefail

# One-key mount/unmount for (d)ArkOS multi-partition images (trixie layout)
#
# trixie 布局 (RG52Mini / RK3562, GPT):
#   p1 = 4M  uboot/dtb blob 区   (不挂载, uboot 不动)
#   p2 = 4M  uboot env 区        (不挂载)
#   p3 = 99M FAT32  "dArkOS_Fat"  -> boot
#   p4 = 11.8G btrfs "ROOTFS"     -> root
#   p5 = 79M FAT16  "ROMS"        -> roms (首启 expandtoexfat.sh 转 exFAT)
#
# 分区不写死编号, 挂载时按 blkid 的 TYPE+LABEL 自动识别, 兼容:
#   - 出厂镜像 (p5=FAT16) 与首启后重新导出的镜像 (p5=exFAT)
#   - 旧 H700 布局 (p1=boot, p2=root, p3=roms)
#
# Usage:
#   sudo ./mount_arkos.sh mount   /path/to/dArkOS_*.img
#   sudo ./mount_arkos.sh unmount
#
# Mount points will be created under: $ARKOS_MNT/{boot,root,roms}
# State (loop device) is stored in:   $ARKOS_MNT/.arkos_loop

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_MNT="${ARKOS_MNT:-$SCRIPT_DIR/mnt}"
STATE_FILE="$BASE_MNT/.arkos_loop"
BOOT_MNT="$BASE_MNT/boot"
ROOT_MNT="$BASE_MNT/root"
ROMS_MNT="$BASE_MNT/roms"

need_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "Please run as root (use sudo)." >&2
    exit 1
  fi
}

ensure_tools() {
  for t in losetup mount umount lsblk blkid; do
    command -v "$t" >/dev/null 2>&1 || {
      echo "Missing tool: $t" >&2
      exit 1
    }
  done
}

write_state() {
  mkdir -p "$BASE_MNT"
  echo "$1" > "$STATE_FILE"
}

read_state() {
  [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || true
}

clear_state() {
  rm -f "$STATE_FILE"
}

mk_mount_dirs() {
  mkdir -p "$BOOT_MNT" "$ROOT_MNT" "$ROMS_MNT"
}

is_mounted() {
  mountpoint -q "$1"
}

mount_if_not() {
  local dev="$1" mnt="$2" fstype="${3:-auto}" opts="${4:-}"
  if is_mounted "$mnt"; then
    echo "Already mounted: $mnt"
    return 0
  fi
  if [[ -n "$opts" ]]; then
    mount -t "$fstype" -o "$opts" "$dev" "$mnt"
  else
    mount -t "$fstype" "$dev" "$mnt"
  fi
  echo "Mounted $dev -> $mnt"
}

# 按 TYPE+LABEL 把 loop 分区归类到 boot/root/roms
classify_partition() {
  local dev="$1"
  local type label part
  type=$(blkid -o value -s TYPE "$dev" 2>/dev/null || true)
  label=$(blkid -o value -s LABEL "$dev" 2>/dev/null || true)
  part="${dev##*loop*p}"   # 分区号, 仅日志用

  case "$type" in
    btrfs|ext4)
      echo "root:$dev:$type"
      ;;
    exfat)
      # exFAT 只会出现在 roms (首启转换后)
      echo "roms:$dev:$type"
      ;;
    ntfs|ntfs3)
      echo "roms:$dev:$type"
      ;;
    vfat|fat|fat16|fat32|msdos)
      case "$(echo "$label" | tr '[:lower:]' '[:upper:]')" in
        ROMS|EASYROMS*)
          echo "roms:$dev:$type"
          ;;
        *)
          # dArkOS_Fat / BOOT / 其他 FAT 一律当 boot
          echo "boot:$dev:$type"
          ;;
      esac
    ;;
    *)
      # 无文件系统签名: p1/p2 uboot 区, 提示后跳过
      echo "skip:$dev:${type:-none} (label=${label:-none}) part p$part"
      ;;
  esac
}

do_mount() {
  local img="$1"

  # 基准镜像只读: 即使只是查看, rw 挂载也会回放/更新 btrfs 元数据,
  # 导致镜像文件落盘字节变化 (sha256 变掉)。基准永远按 ro 挂。
  local ro=no base_img="$SCRIPT_DIR/dArkOS_rg52mini_trixie_06242026.img"
  if [[ -f "$base_img" && "$(readlink -f "$img")" == "$(readlink -f "$base_img")" ]]; then
    ro=yes
    echo "== 基准镜像: 只读挂载 =="
  fi

  # sanity
  [[ -f "$img" ]] || { echo "Image not found: $img" >&2; exit 1; }

  # create loop with partition scan
  local loop
  loop="$(losetup -fP --show "$img")"   # e.g. /dev/loop7
  echo "Loop device: $loop"
  trap 'for m in "$ROMS_MNT" "$ROOT_MNT" "$BOOT_MNT"; do mountpoint -q "$m" && umount "$m" 2>/dev/null || true; done; losetup -d "$loop" 2>/dev/null || true' ERR
  write_state "$loop"

  # wait for kernel to create loopXpN
  sleep 0.5

  # show partitions
  lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT "$loop"

  # mount points
  mk_mount_dirs

  # 扫描全部分区自动归类
  local boot_dev="" root_dev="" roms_dev=""
  local root_fstype="" roms_fstype=""
  local pc role pdev pfs dev
  while IFS= read -r dev; do
    [[ -b "$dev" ]] || continue
    pc="$(classify_partition "$dev")"
    echo "  $dev -> $pc"
    role="$(echo "$pc"  | cut -d: -f1)"
    pdev="$(echo "$pc" | cut -d: -f2)"
    pfs="$(echo "$pc"  | cut -d: -f3)"
    case "$role" in
      boot) boot_dev="$pdev" ;;
      root) [[ -z "$root_dev" ]] && { root_dev="$pdev"; root_fstype="$pfs"; } ;;
      roms) roms_dev="$pdev"; roms_fstype="$pfs" ;;
    esac
  done < <(ls "${loop}"p* 2>/dev/null | sort -V)

  if [[ -z "$boot_dev" || -z "$root_dev" ]]; then
    echo "ERROR: failed to detect boot/root partition (boot=${boot_dev:-none} root=${root_dev:-none})" >&2
    exit 1
  fi

  if [[ "$ro" == "yes" ]]; then
    mount_if_not "$boot_dev" "$BOOT_MNT" vfat "ro,utf8,umask=000"
  else
    mount_if_not "$boot_dev" "$BOOT_MNT" vfat "rw,utf8,umask=000"
  fi

  if [[ "$ro" == "yes" ]]; then
    case "$root_fstype" in
      ext4) mount_if_not "$root_dev" "$ROOT_MNT" ext4 "ro" ;;
      btrfs) mount_if_not "$root_dev" "$ROOT_MNT" btrfs "ro" ;;
      *) echo "Unsupported file system on root partition: $root_fstype" >&2; exit 1 ;;
    esac
  else
    case "$root_fstype" in
      ext4) mount_if_not "$root_dev" "$ROOT_MNT" ext4 ;;
      btrfs) mount_if_not "$root_dev" "$ROOT_MNT" btrfs ;;
      *) echo "Unsupported file system on root partition: $root_fstype" >&2; exit 1 ;;
    esac
  fi

  # roms 按实际文件系统类型挂载 (出厂 FAT16/exFAT, 旧镜像可能 NTFS)
  local romopts="rw"
  [[ "$ro" == "yes" ]] && romopts="ro"
  if [[ -n "$roms_dev" ]]; then
    case "$roms_fstype" in
      exfat)
        mount_if_not "$roms_dev" "$ROMS_MNT" exfat "$romopts,uid=0,gid=0,umask=000"
        ;;
      ntfs|ntfs3)
        mount_if_not "$roms_dev" "$ROMS_MNT" ntfs-3g "$romopts,iocharset=utf8,umask=000" 2>/dev/null ||
          mount_if_not "$roms_dev" "$ROMS_MNT" ntfs "$romopts,iocharset=utf8,umask=000" 2>/dev/null ||
          mount_if_not "$roms_dev" "$ROMS_MNT"
        ;;
      vfat|fat*|msdos)
        mount_if_not "$roms_dev" "$ROMS_MNT" vfat "$romopts,utf8,umask=000"
        ;;
      *)
        mount_if_not "$roms_dev" "$ROMS_MNT"
        ;;
    esac
  else
    echo "No roms partition detected (OK for 2-partition images)"
  fi

  echo
  echo "All set."
  echo "  BOOT -> $BOOT_MNT"
  echo "  ROOT -> $ROOT_MNT"
  echo "  ROMS -> ${ROMS_MNT} (${roms_dev:-none})"
  trap - ERR
}

do_unmount() {
  local loop
  loop="$(read_state)"

  # unmount in reverse order
  for m in "$ROMS_MNT" "$ROOT_MNT" "$BOOT_MNT"; do
    if is_mounted "$m"; then
      umount "$m" || {
        echo "Failed to unmount $m" >&2
        exit 1
      }
      echo "Unmounted $m"
    fi
  done

  # detach loop
  if [[ -n "$loop" && -b "$loop" ]]; then
    losetup -d "$loop" || {
      echo "Failed to detach $loop" >&2
      exit 1
    }
    echo "Detached loop: $loop"
  else
    # try auto-detect any loop that points to our image mounts
    for dev in /dev/loop*; do
      [[ -b "$dev" ]] || continue
      if lsblk -no MOUNTPOINT "$dev" | grep -q "$BASE_MNT" 2>/dev/null; then
        losetup -d "$dev" && echo "Detached loop: $dev"
      fi
    done
  fi

  clear_state
  echo "Done."
}

main() {
  need_root
  ensure_tools

  local cmd="${1:-}"
  case "$cmd" in
    mount)
      [[ $# -ge 2 ]] || { echo "Usage: sudo $0 mount /path/to/image.img"; exit 1; }
      do_mount "$2"
      ;;
    unmount|umount)
      do_unmount
      ;;
    *)
      cat >&2 <<USAGE
Usage:
  sudo $0 mount   /path/to/dArkOS_*.img  # attach, auto-map partitions, mount to \${ARKOS_MNT:-./mnt}/{boot,root,roms}
  sudo $0 unmount                        # unmount all and detach loop device

Notes:
  - Requires: losetup, mount, umount, lsblk, blkid
  - Partitions auto-detected by TYPE+LABEL (trixie: p3/p4/p5, H700: p1/p2/p3)
  - uboot/dtb partitions (no fs signature) are skipped on purpose
  - State file: $STATE_FILE (stores the loop device name)
USAGE
      exit 1
      ;;
  esac
}

main "$@"
