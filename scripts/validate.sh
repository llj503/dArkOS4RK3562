#!/usr/bin/env bash
# Repository validation used by CI.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEVICES=(ngp45ht pocketais)
COMMON_KERNEL="$ROOT/boot/dArkOS/consoles/kernel/5.10"

fail() { echo "ERROR: $*" >&2; exit 1; }

for f in "$ROOT/build_image.sh" "$ROOT/scripts/build_boot.sh" \
         "$ROOT/scripts/build_overlay.py" "$ROOT/scripts/fix_gpt.sh" \
         "$ROOT/scripts/fetch_base.sh"; do
    [ -f "$f" ] || fail "missing build entry point: $f"
done

for f in "$COMMON_KERNEL/Image" "$COMMON_KERNEL/uInitrd"; do
    [ -f "$f" ] || fail "missing common kernel file: $f"
done

for dev in "${DEVICES[@]}"; do
    b="$ROOT/boot/dArkOS/consoles/$dev"
    r="$ROOT/rootfs/dArkOS/$dev"
    for f in "$b/extlinux/extlinux.conf" "$b/firstboot.sh" "$r"; do
        [ -e "$f" ] || fail "missing $dev file: $f"
    done

    fdt=$(sed -n 's/^[[:space:]]*FDT[[:space:]]\+\/\([^[:space:]]*\).*/\1/p' \
        "$b/extlinux/extlinux.conf" | head -1)
    [ -n "$fdt" ] || fail "$dev extlinux has no FDT"
    [ -f "$b/$fdt" ] || fail "$dev extlinux FDT missing: $b/$fdt"

    # A DTB must at least decompile cleanly.
    dtc -I dtb -O dts -o /tmp/darkos4rk3562-$dev.dts "$b/$fdt" 2>/dev/null \
        || fail "$dev DTB does not decompile: $b/$fdt"

        # Firmware/modules are optional: NGP45HT keeps its AIC8800DC stack in the
    # rootfs overlay, Pocket AIS puts D80 firmware + modules on p3 for firstboot.
    for d in firmware modules; do
        if [ -d "$b/$d" ]; then
            find "$b/$d" -type f | grep -q . \
                || fail "$dev $d directory exists but is empty"
        fi
    done

    echo "OK device: $dev"
done

# Shell syntax for the tracked boot/rootfs/scripts.
while IFS= read -r f; do
    first=$(head -1 "$f" 2>/dev/null || true)
    case "$first" in
        *bash*) bash -n "$f" ;;
        *bin/sh*) bash -n "$f" ;;
    esac
done < <(grep -RIl '^#!' "$ROOT/boot" "$ROOT/rootfs" "$ROOT/scripts" 2>/dev/null || true)

bash -n "$ROOT/build_image.sh"

# Python syntax for the build tools.
while IFS= read -r f; do
    PYTHONPYCACHEPREFIX=/tmp/darkos4rk3562-pyc python3 -m py_compile "$f"
done < <(find "$ROOT/scripts" -name '*.py' -type f)

# No device credentials / private keys in the overlays or boot trees.
if find "$ROOT/boot" "$ROOT/rootfs" -type f \
    \( -name 'authorized_keys' -o -name 'id_rsa*' -o -name 'id_ed25519*' \
       -o -name 'ssh_host_*' -o -name '*.nmconnection' \) | grep -q .; then
    fail "credential-like file found in boot/rootfs overlays"
fi
if find "$ROOT/boot" "$ROOT/rootfs" -type d -name .ssh | grep -q .; then
    fail ".ssh directory found in boot/rootfs overlays"
fi
if grep -rIl -E 'BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY|^[[:space:]]*psk=[^[:space:]]' \
    "$ROOT/rootfs/dArkOS" "$ROOT/boot/dArkOS/consoles" \
    --exclude='*.bin' --exclude='*.ko' --exclude='*.dtb' --exclude='*.bmp' \
    --exclude-dir=firmware --exclude-dir=modules 2>/dev/null | grep -q .; then
    fail "private key or WiFi PSK material found in overlays"
fi

echo "validation passed"
