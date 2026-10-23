#!/usr/bin/env python3
"""
apply_panel_lut.py — push a 3D color-correction LUT to the active DRM CRTC.

Reads a LUT file in DRM color_lut format (729 entries × 8 bytes = 5832 bytes,
9×9×9 cube) and applies it via the atomic DRM API as the CRTC's CUBIC_LUT
property. The Rockchip VOP2 driver packs the entries into its hardware
3D-LUT format and the silicon applies the lookup for every pixel at scanout.

Typical invocation:
    sudo apply_panel_lut /etc/panel-lut/current.lut

Notes on master / atomic mode:
  - Setting CUBIC_LUT requires atomic mode (DRM_CLIENT_CAP_ATOMIC).
  - The legacy SetGamma path we used before tolerated running while
    another client (EmulationStation) held DRM master; the atomic path
    may not. If commits fail with EACCES/EPERM, the panel-lut.service
    needs to be reordered to Before=emulationstation.service so the LUT
    is in place before ES grabs master.

Uses libdrm.so.2 via ctypes — no compiled deps beyond the system libdrm.
"""

import ctypes
import ctypes.util
import os
import sys
import time

# 9×9×9 cube
CUBE_N = 9
LUT_ENTRIES = CUBE_N ** 3          # 729
BYTES_PER_ENTRY = 8                # u16 R, G, B, reserved
LUT_BYTES = LUT_ENTRIES * BYTES_PER_ENTRY  # 5832

DRM_NODE = '/dev/dri/card0'

DRM_CLIENT_CAP_ATOMIC = 3
DRM_MODE_OBJECT_CRTC = 0xcccccccc

DRM_MODE_ATOMIC_TEST_ONLY     = 0x0100
DRM_MODE_ATOMIC_NONBLOCK      = 0x0200
DRM_MODE_ATOMIC_ALLOW_MODESET = 0x0400

PROP_NAME = b'CUBIC_LUT'
PROP_SIZE_NAME = b'CUBIC_LUT_SIZE'


# ---------------------------------------------------------------------------
# libdrm bindings (just enough)
# ---------------------------------------------------------------------------

_lib_path = ctypes.util.find_library('drm') or 'libdrm.so.2'
libdrm = ctypes.CDLL(_lib_path, use_errno=True)


class DrmModeRes(ctypes.Structure):
    _fields_ = [
        ('count_fbs',        ctypes.c_int),
        ('fbs',              ctypes.POINTER(ctypes.c_uint32)),
        ('count_crtcs',      ctypes.c_int),
        ('crtcs',            ctypes.POINTER(ctypes.c_uint32)),
        ('count_connectors', ctypes.c_int),
        ('connectors',       ctypes.POINTER(ctypes.c_uint32)),
        ('count_encoders',   ctypes.c_int),
        ('encoders',         ctypes.POINTER(ctypes.c_uint32)),
        ('min_width',        ctypes.c_uint32),
        ('max_width',        ctypes.c_uint32),
        ('min_height',       ctypes.c_uint32),
        ('max_height',       ctypes.c_uint32),
    ]


class DrmModeModeInfo(ctypes.Structure):
    _fields_ = [
        ('clock',       ctypes.c_uint32),
        ('hdisplay',    ctypes.c_uint16),
        ('hsync_start', ctypes.c_uint16),
        ('hsync_end',   ctypes.c_uint16),
        ('htotal',      ctypes.c_uint16),
        ('hskew',       ctypes.c_uint16),
        ('vdisplay',    ctypes.c_uint16),
        ('vsync_start', ctypes.c_uint16),
        ('vsync_end',   ctypes.c_uint16),
        ('vtotal',      ctypes.c_uint16),
        ('vscan',       ctypes.c_uint16),
        ('vrefresh',    ctypes.c_uint32),
        ('flags',       ctypes.c_uint32),
        ('type',        ctypes.c_uint32),
        ('name',        ctypes.c_char * 32),
    ]


class DrmModeCrtc(ctypes.Structure):
    _fields_ = [
        ('crtc_id',          ctypes.c_uint32),
        ('buffer_id',        ctypes.c_uint32),
        ('x',                ctypes.c_uint32),
        ('y',                ctypes.c_uint32),
        ('width',            ctypes.c_uint32),
        ('height',           ctypes.c_uint32),
        ('mode_valid',       ctypes.c_int),
        ('mode',             DrmModeModeInfo),
        ('gamma_size',       ctypes.c_int),
    ]


class DrmModeObjectProperties(ctypes.Structure):
    _fields_ = [
        ('count_props',  ctypes.c_uint32),
        ('props',        ctypes.POINTER(ctypes.c_uint32)),
        ('prop_values',  ctypes.POINTER(ctypes.c_uint64)),
    ]


class DrmModePropertyEnum(ctypes.Structure):
    _fields_ = [
        ('value',    ctypes.c_uint64),
        ('name',     ctypes.c_char * 32),
    ]


class DrmModePropertyRes(ctypes.Structure):
    _fields_ = [
        ('prop_id',       ctypes.c_uint32),
        ('flags',         ctypes.c_uint32),
        ('name',          ctypes.c_char * 32),
        ('count_values',  ctypes.c_int),
        ('values',        ctypes.POINTER(ctypes.c_uint64)),
        ('count_enums',   ctypes.c_int),
        ('enums',         ctypes.POINTER(DrmModePropertyEnum)),
        ('count_blobs',   ctypes.c_int),
        ('blob_ids',      ctypes.POINTER(ctypes.c_uint32)),
    ]


libdrm.drmModeGetResources.restype  = ctypes.POINTER(DrmModeRes)
libdrm.drmModeGetResources.argtypes = [ctypes.c_int]
libdrm.drmModeFreeResources.restype  = None
libdrm.drmModeFreeResources.argtypes = [ctypes.POINTER(DrmModeRes)]

libdrm.drmModeGetCrtc.restype  = ctypes.POINTER(DrmModeCrtc)
libdrm.drmModeGetCrtc.argtypes = [ctypes.c_int, ctypes.c_uint32]
libdrm.drmModeFreeCrtc.restype  = None
libdrm.drmModeFreeCrtc.argtypes = [ctypes.POINTER(DrmModeCrtc)]

libdrm.drmSetClientCap.restype  = ctypes.c_int
libdrm.drmSetClientCap.argtypes = [ctypes.c_int, ctypes.c_uint64, ctypes.c_uint64]

libdrm.drmModeObjectGetProperties.restype  = ctypes.POINTER(DrmModeObjectProperties)
libdrm.drmModeObjectGetProperties.argtypes = [ctypes.c_int, ctypes.c_uint32, ctypes.c_uint32]
libdrm.drmModeFreeObjectProperties.restype  = None
libdrm.drmModeFreeObjectProperties.argtypes = [ctypes.POINTER(DrmModeObjectProperties)]

libdrm.drmModeGetProperty.restype  = ctypes.POINTER(DrmModePropertyRes)
libdrm.drmModeGetProperty.argtypes = [ctypes.c_int, ctypes.c_uint32]
libdrm.drmModeFreeProperty.restype  = None
libdrm.drmModeFreeProperty.argtypes = [ctypes.POINTER(DrmModePropertyRes)]

libdrm.drmModeCreatePropertyBlob.restype  = ctypes.c_int
libdrm.drmModeCreatePropertyBlob.argtypes = [
    ctypes.c_int, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_uint32),
]
libdrm.drmModeDestroyPropertyBlob.restype  = ctypes.c_int
libdrm.drmModeDestroyPropertyBlob.argtypes = [ctypes.c_int, ctypes.c_uint32]

libdrm.drmModeAtomicAlloc.restype  = ctypes.c_void_p
libdrm.drmModeAtomicAlloc.argtypes = []
libdrm.drmModeAtomicFree.restype  = None
libdrm.drmModeAtomicFree.argtypes = [ctypes.c_void_p]
libdrm.drmModeAtomicAddProperty.restype  = ctypes.c_int
libdrm.drmModeAtomicAddProperty.argtypes = [
    ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint64,
]
libdrm.drmModeAtomicCommit.restype  = ctypes.c_int
libdrm.drmModeAtomicCommit.argtypes = [
    ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32, ctypes.c_void_p,
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def find_active_crtcs(fd):
    """Yield (crtc_id, mode_name) for each active CRTC."""
    res_ptr = libdrm.drmModeGetResources(fd)
    if not res_ptr:
        raise RuntimeError(
            f"drmModeGetResources failed on {DRM_NODE}: {os.strerror(ctypes.get_errno())}"
        )
    try:
        res = res_ptr.contents
        for i in range(res.count_crtcs):
            crtc_id = res.crtcs[i]
            crtc_ptr = libdrm.drmModeGetCrtc(fd, crtc_id)
            if not crtc_ptr:
                continue
            try:
                c = crtc_ptr.contents
                if c.mode_valid:
                    yield (c.crtc_id, c.mode.name.decode('ascii', 'replace'))
            finally:
                libdrm.drmModeFreeCrtc(crtc_ptr)
    finally:
        libdrm.drmModeFreeResources(res_ptr)


def find_property_id(fd, crtc_id, name):
    """Return (prop_id, current_value) for the named property, or (None, None)."""
    props_ptr = libdrm.drmModeObjectGetProperties(fd, crtc_id, DRM_MODE_OBJECT_CRTC)
    if not props_ptr:
        return (None, None)
    try:
        props = props_ptr.contents
        for i in range(props.count_props):
            pid = props.props[i]
            pval = props.prop_values[i]
            pres_ptr = libdrm.drmModeGetProperty(fd, pid)
            if not pres_ptr:
                continue
            try:
                pres = pres_ptr.contents
                if pres.name.rstrip(b'\x00') == name:
                    return (pid, pval)
            finally:
                libdrm.drmModeFreeProperty(pres_ptr)
        return (None, None)
    finally:
        libdrm.drmModeFreeObjectProperties(props_ptr)


def load_lut(path):
    """Read the LUT file; return raw bytes."""
    with open(path, 'rb') as f:
        data = f.read()
    if len(data) != LUT_BYTES:
        raise ValueError(
            f"LUT file {path}: {len(data)} bytes, expected {LUT_BYTES} "
            f"({LUT_ENTRIES} entries × {BYTES_PER_ENTRY} bytes)"
        )
    return data


def apply_once(lut_path, verbose=True):
    """One apply attempt. Returns True on success, False if nothing took."""
    data = load_lut(lut_path)
    if verbose:
        print(f"Loaded {lut_path}: {LUT_ENTRIES} entries, {len(data)} bytes")

    fd = os.open(DRM_NODE, os.O_RDWR)
    try:
        rc = libdrm.drmSetClientCap(fd, DRM_CLIENT_CAP_ATOMIC, 1)
        if rc != 0:
            err = ctypes.get_errno()
            raise RuntimeError(
                f"drmSetClientCap(ATOMIC) failed: rc={rc} errno={err} "
                f"({os.strerror(err)})"
            )

        applied_any = False
        for crtc_id, mode_name in find_active_crtcs(fd):
            prop_id, _ = find_property_id(fd, crtc_id, PROP_NAME)
            if prop_id is None:
                if verbose:
                    print(f"CRTC {crtc_id} mode='{mode_name}': "
                          f"no {PROP_NAME.decode()} property — skipping",
                          file=sys.stderr)
                continue

            size_prop_id, size_val = find_property_id(fd, crtc_id, PROP_SIZE_NAME)
            if verbose:
                print(f"CRTC {crtc_id}: mode='{mode_name}' "
                      f"prop_id={prop_id} CUBIC_LUT_SIZE={size_val}")
            if size_val is not None and size_val != LUT_ENTRIES:
                print(f"  warning: hardware reports {size_val} entries, "
                      f"LUT has {LUT_ENTRIES}", file=sys.stderr)

            buf = (ctypes.c_uint8 * len(data)).from_buffer_copy(data)
            blob_id = ctypes.c_uint32(0)
            rc = libdrm.drmModeCreatePropertyBlob(
                fd, ctypes.cast(buf, ctypes.c_void_p), len(data), ctypes.byref(blob_id)
            )
            if rc != 0:
                err = ctypes.get_errno()
                print(f"  drmModeCreatePropertyBlob failed: rc={rc} errno={err} "
                      f"({os.strerror(err)})", file=sys.stderr)
                continue

            req = libdrm.drmModeAtomicAlloc()
            if not req:
                libdrm.drmModeDestroyPropertyBlob(fd, blob_id.value)
                print("  drmModeAtomicAlloc returned NULL", file=sys.stderr)
                continue
            try:
                added = libdrm.drmModeAtomicAddProperty(
                    req, crtc_id, prop_id, blob_id.value
                )
                if added < 0:
                    err = ctypes.get_errno()
                    print(f"  drmModeAtomicAddProperty failed: rc={added} "
                          f"errno={err} ({os.strerror(err)})", file=sys.stderr)
                    continue
                rc = libdrm.drmModeAtomicCommit(fd, req, 0, None)
                if rc != 0:
                    err = ctypes.get_errno()
                    print(f"  drmModeAtomicCommit failed: rc={rc} errno={err} "
                          f"({os.strerror(err)})", file=sys.stderr)
                    continue
                if verbose:
                    print(f"  applied (blob_id={blob_id.value})")
                applied_any = True
            finally:
                libdrm.drmModeAtomicFree(req)
                # The blob is referenced by the CRTC state now; we can drop
                # our reference. The kernel keeps it alive.
                libdrm.drmModeDestroyPropertyBlob(fd, blob_id.value)
        return applied_any
    finally:
        os.close(fd)


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <lut-file>", file=sys.stderr)
        sys.exit(1)

    lut_path = sys.argv[1]

    # Retry loop: when invoked from systemd at boot or on resume, the active
    # CRTC may not be settled yet. APPLY_RETRIES/APPLY_RETRY_DELAY env vars
    # let the operator tune; defaults handle the typical boot race.
    retries = int(os.environ.get('APPLY_RETRIES', '20'))
    delay = float(os.environ.get('APPLY_RETRY_DELAY', '0.5'))

    last_err = None
    for attempt in range(retries):
        try:
            if apply_once(lut_path, verbose=(attempt == 0)):
                return
            last_err = "no CRTC accepted the LUT"
        except Exception as e:
            last_err = repr(e)
        if attempt < retries - 1:
            time.sleep(delay)

    print(f"Gave up after {retries} attempts: {last_err}", file=sys.stderr)
    sys.exit(2)


if __name__ == '__main__':
    main()
