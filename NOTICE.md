# Component licenses and provenance

The MIT `LICENSE` covers the dArkOS4RK3562 repository layout, the CI/build
scripts and the device overlay glue written for this repository.

The following components keep their original licenses/provenance:

- **dArkOS / ArkOS** userland, scripts and boot files: GPL-2.0-or-later and the
  upstream dArkOS/ArkOS notices.
- **Linux kernel and kernel patches** (`src/dArkOS/ngp45ht/kernel`): GPL-2.0.
  The full kernel source is not vendored here; use the upstream
  `llj503/kernel_rk3562` `ngp45ht` branch.
- **EmulationStation** binary/resources: GPL-3.0-or-later (EmulationStation
  fork used by dArkOS). The Pocket AIS source changes are shipped as a patch
  under `src/dArkOS/pocketais/es`.
- **RetroArch** and libretro cores: their upstream licenses.
- **AIC8800** kernel modules/firmware: vendor distribution, as shipped in the
  base dArkOS images; redistributed here only as the boot payload required by
  the matching images. Verify the vendor terms before redistributing.
- **Themes/artwork** (`es-theme-nes-box` and boot logos/battery bitmaps):
  their upstream/theme authors' terms.
- **arkos4clone** layout/scripts: MIT, copyright lcdyk; see `LICENSE`.

No SSH host keys, user WiFi profiles, `authorized_keys`, user ROMs or BIOS files
are included. Base images and full userdata images must be handled separately.
