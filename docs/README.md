# docs

- [Repository README](../README.md) — base images, layout, build and CI.
- [Component licenses](../NOTICE.md)

This repository is **build-only**: boot payloads under
`boot/consoles/`, rootfs overlays under `rootfs/`, and the
scripts/CI that assemble and release them. Kernel, DTS, panel GUI and
EmulationStation sources live in their own projects:

- `llj503/kernel_rk3562` (branch `ngp45ht`)
- `llj503/dArkOS_ngp45ht`
- `llj503/dArkOS-PokectAis`
- the EmulationStation fcamod-351v tree

Base dArkOS images and user ROMs/BIOS are external.
