# U-Boot / boot chain

No U-Boot binaries are tracked in this repository. The two consoles use
different chains, and only one of them has a bootloader on the TF card.

## NGP45HT — board bootloader on the TF card

Layout on the card (sector size 512):

| Region | Sectors | Content |
| --- | --- | --- |
| GPT / MBR | 0–63 | partition table |
| idbloader area | 64–16383 | Rockchip `RKNS` idbloader (DDR init + SPL), dumped from this board |
| p1 `uboot` | 16384–24575 | 4 MiB U-Boot FIT, two mirrored 2 MiB halves |
| p2 `resource` | 24576–32767 | all zero in the NGP45HT base image, unused by the extlinux path |
| p3 `dArkOS_Fat` | 32768–235519 | `Image`, `uInitrd`, DTB, `extlinux/extlinux.conf` |
| p4 rootfs | 237568– | BTRFS |

Chain: BootROM → idbloader → U-Boot FIT → `extlinux.conf` on p3 → kernel.
U-Boot is patched to scan the TF first (`boot_targets = "mmc1 mmc0"`), so the
card boots without touching the eMMC.

**Where the images came from (not another board's image):**

1. The idbloader and stock U-Boot were dumped from *this* NGP45HT's eMMC:

   ```bash
   dd if=/dev/mmcblk0   bs=1M count=8 of=ngp_bl8m.img
   dd if=/dev/mmcblk0p1 bs=1M count=4 of=ngp_uboot.img
   ```

   `ngp_bl8m.img` is the first 8 MiB; only sectors 64–16383 are written to the
   image. The board's DDR init is board-specific, so an RG43H/RG52 U-Boot or
   idbloader is not a substitute.

2. The stock 4 MiB U-Boot FIT was modified offline with
   `darkos-uboot-tool.py preset charge` (from the aislpc-bootloader-tool
   submodule). The preset:

   - trims `boot_targets` to `mmc1 mmc0` (SD first, and removes mtd/usb/pxe/dhcp
     scans; the stock environment is 100% full, so this also makes room);
   - sets `bootcmd = "run distro_bootcmd;boot_fit;bootrkp;"`;
   - sets `preboot = "dvfs;run rkimg_bootdev;charge"` so the charge animation
     runs before the OS;
   - replaces U-Boot's own FDT component (7,479 bytes) with a 12,151-byte
     charge-enabled DTB (I2C0, RK817 PMIC/regulators/pwrkey/battery/charger,
     charge-animation nodes, LED GPIO3_A0/A1);
   - recomputes the FIT component SHA-256 values and mirrors both 2 MiB halves.

   The result is `ngp_uboot_sdfirst.img`. The tool never flashes the eMMC; it
   edits the 4 MiB file in place.

3. The 20261013 image was assembled by writing the idbloader at sector 64 and
   this patched U-Boot at sector 16384. Later images (20261015/17/18) cloned
   that boot area forward. The published base image used by this repository
   already contains it.

The current build does **not** regenerate or write U-Boot: `build_image.sh
ngp45ht` only writes p3 (16 MiB) and optionally p4. p1/p2 and sectors 64–16383
are inherited from the base image. Local reference copies (not tracked):

- `F:\darkos\_work\ngp_bl8m.img` — 8 MiB eMMC boot area dump
- `F:\darkos\_work\ngp_uboot.img` — stock 4 MiB U-Boot
- `F:\darkos\_work\ngp_uboot_sdfirst.img` — patched SD-first + charge U-Boot
- `F:\darkos\bootloader_tool\tool\darkos-uboot-tool.py` — editor

Verified against `F:\darkos\ngp45ht_board.img`: the idbloader region (sectors
64–16383) is byte-identical to the dump (`sha256 1ac18a93…`), and p1 is
byte-identical to `ngp_uboot_sdfirst.img` (`sha256 1b36c405…`).

## Pocket AIS — eMMC U-Boot, no bootloader on the TF card

The Pocket AIS runs its vendor AisOS U-Boot from the **internal eMMC**. The TF
card is payload only:

- sectors 64–32767 (idbloader + p1/p2 areas) are zeroed;
- the GPT keeps p1/p2 type GUIDs `a60b0000-…` (`uboot`) and `d46e0000-…`
  (`resource`), and p3 gets attribute `0x4` (bootable); both primary and backup
  GPTs and their CRC32s are repaired by `scripts/fix_gpt.sh`;
- the eMMC U-Boot then reads p3 `extlinux/extlinux.conf` and boots dArkOS.

This is measured behaviour, not a guess: with distro `sgdisk` type GUIDs
(Linux filesystem) and p3 attribute 0, the eMMC U-Boot ignored the TF and booted
AisOS; restoring the Rockchip GUIDs and the bootable flag made it boot the TF.

`build_image.sh pocketais` zeroes sectors 64–32767 again and runs the GPT fix on
the copy. It never writes a bootloader and never touches the eMMC.

## Warning

Do not flash or "upgrade" the eMMC bootloader for a cosmetic boot logo. The
Pocket AIS boot path depends on the vendor eMMC U-Boot, and a bad write can brick
the internal AisOS boot chain. All experiments belong on the TF card.
