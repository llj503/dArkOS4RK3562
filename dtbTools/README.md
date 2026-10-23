# dtbTools

The device DTBs are prebuilt in `boot/dArkOS/consoles/<device>/`; their sources
live under `src/dArkOS/`:

- NGP45HT: `src/dArkOS/ngp45ht/kernel/rk3562-ngp45ht.dts` (kernel-tree board
  DTS), `rk3562-ngp45ht.dts.tpl`, `ngp45ht_defconfig`, plus the four kernel
  patches.
- Pocket AIS: `src/dArkOS/pocketais/dts/ro520c_aic.dts` (full decompiled DTS)
  and `patch_dtb.py` (the `a-key` → `b-key` hardware key mapping).

Validation uses `dtc`:

```bash
dtc -I dtb -O dts -o /tmp/board.dts boot/dArkOS/consoles/ngp45ht/rk3562-ngp45ht.dtb
dtc -I dts -O dtb -o /tmp/ro520c.dtb src/dArkOS/pocketais/dts/ro520c_aic.dts
```

The DTB tooling from arkos4clone (DTB analysis/customization) is not duplicated
here; the build/validation scripts only use `dtc`.
