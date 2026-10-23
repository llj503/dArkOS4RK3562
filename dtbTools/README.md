# dtbTools

The device DTBs are prebuilt in `boot/consoles/<device>/`. Their sources
are not kept in this build-only repository:

- NGP45HT: `rk3562-ngp45ht.dts`, `rk3562-ngp45ht.dts.tpl`,
  `ngp45ht_defconfig` and the four kernel patches live in
  `llj503/kernel_rk3562`, branch `ngp45ht`.
- Pocket AIS: the full `ro520c_aic.dts` and `patch_dtb.py` (the `a-key` →
  `b-key` mapping) live with the Pocket AIS source project.

Validation only inspects the shipped DTB with `dtc`:

```bash
dtc -I dtb -O dts -o /tmp/board.dts \
  boot/consoles/ngp45ht/rk3562-ngp45ht.dtb
dtc -I dtb -O dts -o /tmp/board.dts \
  boot/consoles/pocketais/rk3562-ro520c.dtb
```

The DTB tooling from arkos4clone (DTB analysis/customization) is not duplicated
here; the build/validation scripts only use `dtc`.
