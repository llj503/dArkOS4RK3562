# NGP45HT source

This directory holds the NGP45HT-specific source changes used by the
`boot/dArkOS/consoles/ngp45ht` payload and `rootfs/dArkOS/ngp45ht` overlay.

## Kernel

`kernel/` contains:

- `0001-rk3562-joystick-per-axis-inversion-and-gpio-triggers.patch`
  (`drivers/input/joystick/rk3562-joystick.c`; per-axis inversions and GPIO
  trigger axes)
- `0002-arm64-dts-rockchip-add-rk3562-ngp45ht-board.patch`
  (`rk3562-ngp45ht.dts` + DTS Makefile)
- `0003-arm64-configs-add-ngp45ht_defconfig.patch`
- `0004-arm64-dts-rockchip-label-wireless-and-charge-anim-in-darkos-dtsi.patch`
- `rk3562-ngp45ht.dts`, `rk3562-ngp45ht.dts.tpl`, `ngp45ht_defconfig`,
  `apply.sh`

The full kernel tree is not vendored. Apply the patches to
`llj503/kernel_rk3562` (`ngp45ht` branch) or build with
`tools/slimbuild.sh`; the shipped `Image` and the two AIC8800DC modules must
come from the same kernel.

## Userland

- `panel-led/`: `ngp_panel_gui.c`, `ngp_wifi_gui.c`, `ngp-led-off.c`,
  `spishim.c`, panel/LED/network/Chinese/arcade scripts, services and assets.
- `ngp-panel/`: panel colour/BCSH restore, `panelprop.py`, `paneladj.sh`,
  installer and service.
- `power/`: NGP power-key config and battery shim.
- `boot/`: `boot-firstboot.sh` and `boot-ngp-expand.sh` sources.
- `tools/`: boot speed/zram, SSH always-on, btrfs directory scanner, ROM
  pool, shaders, core updater, image clone/compare/verify and build helpers.

## Building

```bash
bash kernel-patches/apply.sh <kernel_rk3562>
bash tools/slimbuild.sh          # Image + DTB + AIC8800DC modules
```

The NGP45HT base image is external (`dArkOS_ngp45ht_trixie_20261015.img.xz`);
this repository only supplies the p3 boot payload/rootfs overlay and the source
changes.  Do not publish a live-card image: it contains the device's SSH and
WiFi data.
