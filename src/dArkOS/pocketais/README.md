# Pocket AIS source

This directory holds the Pocket AIS-specific source changes used by
`boot/dArkOS/consoles/pocketais` and `rootfs/dArkOS/pocketais`.

## Device tree

- `dts/ro520c_aic.dts` — full Pocket AIS DTS (base `rk3562-ro520c.dts`).
- `dts/patch_dtb.py` — the `a-key` → `b-key` key-name change.
- The compiled `rk3562-ro520c.dtb` is in the boot console directory.

Changes vs the base DTS: `wifi_chip_type = "aic8800D80"`, the `a-key` →
`b-key` channel name and `left-stick-invert`.  The RK817 audio properties
(`use-ext-amplifier`, `hp2extamplifier`, `hp-ctl-gpios`) were already present in
the base DTS and are used unchanged.

## EmulationStation

`es/emulationstation-pocketais.patch` changes six files in the
EmulationStation-fcamod 351v fork:

- `GuiGamelistOptions.cpp/.h`: per-game `EMULATOR / CORE` advanced entry.
- `GuiMetaDataEd.cpp/.h`: custom title and default-emulator fallback for the
  core list.
- `GuiTools.cpp`: network/panel scripts at the top of the script list.
- `es-core/.../BatteryIndicatorComponent.cpp`: battery icon layout.

`es/es_advanced_menu.patch` is the smaller upstream patch for the advanced menu.
The compiled ES binary/resources are in the rootfs overlay.

## Image and rootfs helpers

- `image_build/`: `build_image_20261020.sh`, `fix_gpt_20261020.py`,
  `fix_suspend_20261020.py`, `pocketais-autoexpand.sh`, `sanitize_p4.sh`,
  `finalize_release.sh`, `raw2png.js`.
- `rootfs/`: the battery shim, USB role/mode scripts and systemd units that
  are installed in the rootfs overlay.

The Pocket AIS base image is external
(`pocketAis-dArkOS-20261020-autoexpand-sanitized.img.xz`); the overlay in this
repository contains the ES/theme/RA/settings and device scripts, not the
complete rootfs.  AIC8800D80 firmware/modules are in the boot p3 payload.
