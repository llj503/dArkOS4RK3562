# Changelog

## 2026-10-23 — single build entry point and release CI

- Renamed `scripts/build_boot_bundle.sh` → `scripts/build_boot.sh`,
  `scripts/fix_gpt_20261020.py` → `scripts/fix_gpt.py`, and merged
  `build_update_tar.sh` + `make_update_tar.py` into `scripts/build_overlay.py`.
- Root `build_image.sh` is the single entry point. With no arguments it builds
  both consoles' p3 image, rootfs overlay and `SHA256SUMS.txt` under `out/`;
  `--base` copies a base image and applies the artifacts to it.
- Replaced the validate/build and release workflows with
  `.github/workflows/build.yml`: validate → create/reuse a draft
  `dArkOS4RK3562-YYYYMMDD` release → build both devices in a matrix → upload
  the artifacts and generated `SHA256SUMS.txt` to the draft (arkos4clone flow).

## 2026-10-23 — build-only cleanup

- Removed `src/` from the repository. This repo now only carries boot payloads,
  rootfs overlays, build scripts and CI. Kernel/DTS/GUI/EmulationStation sources
  stay in their owning projects (`llj503/kernel_rk3562` branch `ngp45ht`,
  `llj503/dArkOS_ngp45ht`, `llj503/dArkOS-PokectAis`, ES fcamod tree).
- Moved the only build-time dependency on that tree, `fix_gpt.py`, to
  `scripts/`; `build_image.sh` now calls it there.
- `validate.sh` no longer compiles source DTS or Python from `src/`; it
  decompiles the shipped DTBs and syntax-checks the build scripts only.

## 2026-10-23 — initial dArkOS4RK3562 layout

- Repository laid out after `arkos4clone`: `boot/dArkOS/consoles/<device>`,
  `rootfs/dArkOS/<device>`, `scripts/`, `uboot/`,
  `roms/`, `dtbTools/`, `build_image.sh`, `.github/workflows`.
- Added two RK3562 consoles:
  - `ngp45ht` (XIFAN NGP45HT; AIC8800DC USB WiFi)
  - `pocketais` (Pocket AIS; AIC8800D80 SDIO WiFi)
- Imported the NGP45HT boot payload and prebuilt device files; imported the
  Pocket AIS boot payload, rootfs overlays and sanitized boot/settings.
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
- Added `scripts/build_overlay.py` so overlay modes are content-based and
  identical on Windows and CI (a Windows checkout reports 0777 for everything),
  with fixed entry mtimes for byte-identical repeated builds.
- Local verification 2026-10-23: clean rebuild of both p3 bundles and both
  overlays; p3 contents, extlinux FDT, kernel/initrd hashes and overlay
  extraction checked; `build_image.sh full-image mode` exercised end-to-end on a
  synthetic 512 MiB BTRFS base (p3 at 16 MiB, p4 at 116 MiB).
- `build_boot.sh`/`validate.sh` treat `firmware/` and `modules/` as
  optional (Pocket AIS needs them on p3, NGP45HT keeps them in the rootfs).
- Added CI: validation plus per-device p3/rootfs artifacts; a manual
  release workflow publishes the artifacts (base images are external).
- No full raw/xz images, user ROMs, SSH host keys, WiFi profiles or
  `authorized_keys` are tracked.
