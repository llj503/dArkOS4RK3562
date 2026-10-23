# dArkOS4RK3562

dArkOS boot payloads, rootfs overlays and source patches for two **RK3562**
handhelds, organized after [`arkos4clone`](https://github.com/lcdyk0517/arkos4clone).
This repository does **not** contain full disk images; it contains the
device-specific files needed to turn a base dArkOS RK3562 image into the
NGP45HT or Pocket AIS build.

## Consoles

| Console | Hardware | WiFi | Base dArkOS image |
| --- | --- | --- | --- |
| `ngp45ht` | XIFAN NGP45HT, RK3562, 2 GB, 1024×768 | AIC8800DC **USB** | `dArkOS_ngp45ht_trixie_20261020.img.xz`, 12,884,901,888 B raw |
| `pocketais` | Pocket AIS, RK3562, 2 GB, 1024×768 | AIC8800D80 **SDIO** | `pocketAis-dArkOS-20261020-autoexpand-sanitized.img.xz`, 13,019,137,024 B raw |

Base images are external, not tracked. Obtain the NGP45HT image from
[`llj503/dArkOS_ngp45ht`](https://github.com/llj503/dArkOS_ngp45ht/releases)
and the sanitized Pocket AIS image from
[`llj503/dArkOS-PokectAis`](https://github.com/llj503/dArkOS-PokectAis/releases).
Never publish an image made from your own live card: it can contain device
SSH/WiFi credentials.

## Layout

The layout intentionally follows `arkos4clone`:

```text
.github/workflows/          CI: validate, build both devices, upload draft release
boot/dArkOS/
  clone.sh                  common firstboot wrapper / overlay installer
  expandtoexfat.sh          p5 expansion reference
  consoles/
    kernel/5.10/            common Image + uInitrd
    ngp45ht/                extlinux, DTB, firstboot, ngp-expand, battery BMPs
    pocketais/              extlinux, DTB, firstboot, AIC8800D80 firmware/modules
rootfs/dArkOS/
  common/                   shared scripts (perfmax/perfnorm, sleep, ngp-core-update)
  ngp45ht/                  AIC8800DC stack, panel/LED/network GUI, services
  pocketais/                Pocket AIS ES, theme, RA config, battery/USB/sleep scripts
scripts/                    build_boot.sh, build_overlay.py, fix_gpt.py,
                            fetch_base.sh, validate.sh
uboot/                      boot-chain notes (no U-Boot binaries)
roms/                       image/theme placeholder, no games or BIOS
dtbTools/                   DTB inspection notes (sources external)
build_image.sh              build a complete system image from a base image
```

## Build

`build_image.sh` produces a complete, flashable system image (12–13 GiB raw).
It needs Linux, root, loop devices and BTRFS:

```bash
# use a local base image
sudo ./build_image.sh ngp45ht --base /path/dArkOS_ngp45ht.img
sudo ./build_image.sh pocketais --base /path/pocketAis.img --output out/pocketais.img

# or download, verify and unpack the published base first
sudo ./build_image.sh ngp45ht --fetch-base
sudo ./build_image.sh pocketais --fetch-base
```

Default output is `out/DarkOS4RK3562-<device>.img`. `--outdir DIR` moves the
download/default output, `--in-place` modifies `--base` directly instead of
copying it. The base image is never modified otherwise. Base URLs and checksums
are in [`scripts/fetch_base.sh`](scripts/fetch_base.sh); the compressed bases
are about 4.2 GiB (NGP45HT) and 3.0 GiB (Pocket AIS).

The builder writes p3 at 16 MiB and extracts the rootfs overlay into the BTRFS
p4 at 116 MiB. For Pocket AIS it also zeroes sectors 64–32767 and runs
`scripts/fix_gpt.py` to restore the Rockchip p1/p2 type GUIDs, the p3 bootable
attribute and both GPT CRCs. The base images' p5 is left as-is; the device
firstboot/expand script handles `/roms`.

p3 and the rootfs overlay are **internal intermediates** in a temporary
directory and are deleted after the image is assembled. No update package is
built or published. For debugging, the helpers can still be called directly:

```bash
./scripts/build_boot.sh ngp45ht /tmp/p3.img
./scripts/build_overlay.py ngp45ht /tmp/overlay.tar
```

### What goes into the image

The p3 FAT contains `Image`, `uInitrd`, `extlinux/extlinux.conf`, the device
DTB, firstboot/expansion scripts, `fstab.exfat` and battery bitmaps. Firmware
and kernel modules are only placed on p3 when the console keeps them there
(Pocket AIS); the NGP45HT rootfs overlay carries its AIC8800DC firmware and
`aic8800_fdrv_usb.ko` instead.

NGP45HT uses the fixed `ngp-expand.sh` (unmount before `mkfs`, byte-sized
`mkfs.exfat -c`, FAT32 fallback, mergerfs pool regenerated from
`ngp-rompool.sh`). The Pocket AIS boot bundle keeps the stock
`expandtoexfat.sh`.

The rootfs overlay wins over `common`. Modes are assigned by
`scripts/build_overlay.py` (shebang/ELF → 0755, `panel.conf` 0664,
`led.conf` 0666, everything else 0644), because a Windows checkout cannot
represent the executable bit. Entry mtimes are fixed, so repeated overlay
builds are byte-identical.

The NGP45HT overlay ships prebuilt aarch64 `ngp-panel-gui`, `ngp-wifi-gui` and
`ngp-led-off`, built from the C sources in `opt/ngp-panel/src`. It also installs
`/usr/local/sbin/ngp45ht-update.sh`, which is called by `clone.sh` and by the
NGP45HT `firstboot.sh`: it disables the replaced stock menu entries
(`屏幕色温.sh`, `LED Settings.sh`, `网络信息.sh`, `Wifi.sh`), applies the
Chinese menu rename, enables the panel/LED/WiFi/zram services, and runs
`ngp-bootspeed-fix.sh`. `ws2812-common` is not shipped; the stick-LED service
is only enabled when it already exists on the image.

### Validate

```bash
./scripts/validate.sh
```

It checks the device layout, DTBs (`dtc` decompile), shell/Python syntax,
executable scripts and rejects credential-like files (`authorized_keys`,
`*.nmconnection`, private key headers, WiFi PSKs) from the overlays.

## CI

[`.github/workflows/build.yml`](.github/workflows/build.yml) follows the
`arkos4clone` release flow, for **system images only**:

1. `guard` validates the repository, checks the selected devices and creates
   (or reuses) a **draft** release tagged `dArkOS4RK3562-YYYYMMDD`
   (Asia/Shanghai);
2. one job per selected device runs `./build_image.sh <device> --fetch-base`,
   compresses the raw image to `.img.xz`, splits it into `<2 GiB` parts and
   generates `SHA256SUMS-<device>.txt`;
3. the parts and checksums are uploaded to the draft release with
   `gh release upload --clobber`.

Trigger it from **Actions → dArkOS4RK3562 system images → Run workflow** and
choose NGP45HT and/or Pocket AIS. It is manual on purpose: each run downloads
a 3–4 GiB base, builds a 12–13 GiB image and compresses it again, which is too
heavy for every push. Publish the draft from the GitHub UI when the assets look
right. No update packages are built or uploaded.

## Build inputs and sources

This repository is **build-only**: it carries the prebuilt boot payloads, rootfs
overlays and the scripts/CI that assemble complete system images. It deliberately has
no kernel, DTS or EmulationStation source tree.

When a source change is needed, clone the owning project, build there, and drop
the resulting `Image` / DTB / `.ko` / GUI binary into the matching `boot/` or
`rootfs/` directory here:

| Component | Source repository |
| --- | --- |
| RK3562 kernel, joystick driver, NGP45HT DTS/defconfig | `llj503/kernel_rk3562`, branch `ngp45ht` |
| NGP45HT dArkOS board support, panel/WiFi GUI, tools | `llj503/dArkOS_ngp45ht` |
| Pocket AIS dArkOS image/build work | `llj503/dArkOS-PokectAis` |
| dArkOS / ArkOS base | upstream dArkOS/ArkOS trees |
| EmulationStation fork | the fcamod-351v tree used for the AIS per-game menu |

Device specifics kept here as build inputs:

- NGP45HT: `rk3562-ngp45ht.dtb`, fixed `firstboot.sh`/`ngp-expand.sh`,
  AIC8800DC firmware and USB modules, panel/LED/WiFi binaries.
- Pocket AIS: `rk3562-ro520c.dtb`, firstboot + AIC8800D80 firmware/modules on
  p3, ES binary/theme/RA config in the rootfs overlay.
- Both boot bundles use the same 5.10.226 `Image` and `uInitrd`.

## Credits

- [arkos4clone](https://github.com/lcdyk0517/arkos4clone) — MIT layout and
  porting approach.
- [dArkOS_ngp45ht](https://github.com/llj503/dArkOS_ngp45ht) — NGP45HT dArkOS
  image and board support.
- [dArkOS-PokectAis](https://github.com/llj503/dArkOS-PokectAis) — Pocket AIS
  dArkOS port and sanitized image.
- dArkOS / ArkOS, EmulationStation, RetroArch, Rockchip BSP, AIC8800 vendors.

See [`NOTICE.md`](NOTICE.md) for component licenses.

## Security

No full images, user ROMs/BIOS, SSH host keys, WiFi profiles or
`authorized_keys` are tracked. The Pocket AIS overlay comes from a sanitized
rootfs; the NGP45HT base image contains its own historical device data and must
not be published as-is. The firstboot scripts accept a user-provided
`/boot/authorized_keys`; no key is included.
