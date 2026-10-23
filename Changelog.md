# Changelog

## 2026-10-23 — initial dArkOS4RK3562 layout

- Repository laid out after `arkos4clone`: `boot/dArkOS/consoles/<device>`,
  `rootfs/dArkOS/<device>`, `src/dArkOS/<device>`, `scripts/`, `uboot/`,
  `roms/`, `dtbTools/`, `build_image.sh`, `.github/workflows`.
- Added two RK3562 consoles:
  - `ngp45ht` (XIFAN NGP45HT; AIC8800DC USB WiFi)
  - `pocketais` (Pocket AIS; AIC8800D80 SDIO WiFi)
- Imported the NGP45HT boot payload, kernel patches, panel/WiFi GUI sources and
  device scripts; imported the Pocket AIS boot payload, `ro520c` DTS, ES
  patch, rootfs overlays and sanitized boot/settings.
- NGP45HT boot bundle uses the fixed `firstboot.sh` + `ngp-expand.sh` (the p3
  copies from the 20261015 image still had the `exit 0` dead tail and the
  mkfs-before-umount / `-c 16K` bugs). `expandtoexfat.sh` is not used there.
- NGP45HT rootfs overlay now carries the AIC8800DC firmware/USB modules,
  `/opt/ngp-panel` (scripts + prebuilt aarch64 `ngp-panel-gui`,
  `ngp-wifi-gui`, `ngp-led-off`), LED helpers, panel/LED/WiFi services,
  `ngp-rompool.sh`, `ngp-bootspeed-fix.sh` and `ngp45ht-update.sh`.
  `clone.sh` runs the update script before `firstboot.sh` (which reboots);
  the NGP45HT firstboot also calls it, so images with the overlay pre-applied
  (no `clone.sh` run) still enable the services and disable replaced menus.
- Removed the phantom `PARTLABEL=swap` line from both `fstab.exfat` files; it
  cost the full 90 s `DefaultDeviceTimeoutSec` at boot. NGP45HT gets zram
  swap instead via `ngp-bootspeed-fix.sh`.
- Added `scripts/make_update_tar.py` so overlay modes are content-based and
  identical on Windows and CI (a Windows checkout reports 0777 for everything),
  with fixed entry mtimes for byte-identical repeated builds.
- Local verification 2026-10-23: clean rebuild of both p3 bundles and both
  overlays; p3 contents, extlinux FDT, kernel/initrd hashes and overlay
  extraction checked; `build_image.sh --rootfs` exercised end-to-end on a
  synthetic 512 MiB BTRFS base (p3 at 16 MiB, p4 at 116 MiB).
- `build_boot_bundle.sh`/`validate.sh` treat `firmware/` and `modules/` as
  optional (Pocket AIS needs them on p3, NGP45HT keeps them in the rootfs).
- Added CI: validation plus per-device p3/rootfs artifacts; a manual
  release workflow publishes the artifacts (base images are external).
- No full raw/xz images, user ROMs, SSH host keys, WiFi profiles or
  `authorized_keys` are tracked.
