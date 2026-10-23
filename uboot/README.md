# uboot

The two RK3562 consoles use different boot chains:

- **NGP45HT**: the published NGP45HT dArkOS image carries its own RKNS
  idbloader and the patched vendor U-Boot in p1/p2.  The NGP45HT base image is
  the board image; this repository only overlays p3/p4.
- **Pocket AIS**: the eMMC U-Boot is the boot loader.  The TF p1/p2 and the
  Rockchip idbloader (sectors 64–32767) must be zeroed so the eMMC U-Boot reads
  p3 `extlinux`.  `build_image.sh pocketais` performs this and repairs the GPT
  (p1/p2 type GUIDs, p3 bootable attribute, CRC32).

No U-Boot binaries are tracked here.  Do not flash the eMMC bootloader for a
cosmetic boot logo; that can brick the internal AisOS boot path.
