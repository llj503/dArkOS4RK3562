#!/usr/bin/env python3
import struct
import uuid
import zlib
import os
import sys

PATH = sys.argv[1] if len(sys.argv) > 1 else r"F:\pocketAis\darkos\pocketAis-dArkOS-20261020-autoexpand.img"
P1_TYPE = uuid.UUID("a60b0000-0000-4c7e-8000-015e00004db7").bytes_le
P2_TYPE = uuid.UUID("d46e0000-0000-457f-8000-220d000030db").bytes_le

def crc32(data):
    return zlib.crc32(data) & 0xffffffff

def load_header(f, lba):
    f.seek(lba * 512)
    head = f.read(512)
    if head[:8] != b"EFI PART":
        raise SystemExit(f"bad GPT header at LBA {lba}")
    hsize = struct.unpack_from("<I", head, 12)[0]
    if hsize < 92 or hsize > 512:
        raise SystemExit(f"bad header size {hsize}")
    return bytearray(head[:hsize])

def patch_entries(f, header, p1, p2, p3_attr):
    entry_lba = struct.unpack_from("<Q", header, 72)[0]
    num = struct.unpack_from("<I", header, 80)[0]
    esize = struct.unpack_from("<I", header, 84)[0]
    f.seek(entry_lba * 512)
    entries = bytearray(f.read(num * esize))
    if len(entries) != num * esize:
        raise SystemExit("short partition entry array")
    entries[0:16] = p1
    entries[esize:esize + 16] = p2
    struct.pack_into("<Q", entries, 2 * esize + 48, p3_attr)
    struct.pack_into("<I", header, 88, crc32(bytes(entries)))
    struct.pack_into("<I", header, 16, 0)
    struct.pack_into("<I", header, 16, crc32(bytes(header)))
    f.seek(entry_lba * 512)
    f.write(entries)
    return header

path = PATH
size = os.path.getsize(path)
with open(path, "r+b") as f:
    primary = load_header(f, 1)
    backup_lba = struct.unpack_from("<Q", primary, 32)[0]
    print("image", path, size, "backup_lba", backup_lba)
    primary = patch_entries(f, primary, P1_TYPE, P2_TYPE, 0x4)
    f.seek(512)
    f.write(primary)
    backup = load_header(f, backup_lba)
    backup = patch_entries(f, backup, P1_TYPE, P2_TYPE, 0x4)
    f.seek(backup_lba * 512)
    f.write(backup)
    f.flush()
    os.fsync(f.fileno())

# verify both headers and entries
with open(path, "rb") as f:
    for lba, label in ((1, "primary"), (backup_lba, "backup")):
        h = load_header(f, lba)
        elba = struct.unpack_from("<Q", h, 72)[0]
        num = struct.unpack_from("<I", h, 80)[0]
        esize = struct.unpack_from("<I", h, 84)[0]
        f.seek(elba * 512)
        entries = f.read(num * esize)
        hcrc = struct.unpack_from("<I", h, 16)[0]
        h[16:20] = b"\0\0\0\0"
        calc = zlib.crc32(bytes(h)) & 0xffffffff
        ecrc = struct.unpack_from("<I", h, 88)[0]
        ecalc = zlib.crc32(entries) & 0xffffffff
        print(f"{label}: header_crc={'OK' if hcrc == calc else 'BAD'} entries_crc={'OK' if ecrc == ecalc else 'BAD'}")
        for i in range(3):
            e = entries[i * esize:(i + 1) * esize]
            tg = uuid.UUID(bytes_le=e[:16])
            attr = struct.unpack_from("<Q", e, 48)[0]
            first, last = struct.unpack_from("<QQ", e, 32)
            name = e[56:128].decode("utf-16le").split("\0")[0]
            print(f"  p{i+1} type={tg} {first}-{last} attr={attr:#x} name={name}")
