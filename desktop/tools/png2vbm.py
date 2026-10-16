#!/usr/bin/env python3
"""Convert a PNG to the VBM1 bitmap the desktop's skins use.

VBM1: 'VBM1', width and height as little-endian u16, one reserved byte, then
RGBA, row-major. Vinix has no PNG decoder, so skins carry this instead.
"""
import struct
import sys


def png_to_vbm(src, dst):
    from PIL import Image

    im = Image.open(src).convert("RGBA")
    w, h = im.size
    if not (1 <= w <= 1024 and 1 <= h <= 1024):
        raise SystemExit(f"{src}: {w}x{h} is outside 1..1024")
    with open(dst, "wb") as f:
        f.write(b"VBM1" + struct.pack("<HH", w, h) + b"\0")
        f.write(im.tobytes())


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: png2vbm.py in.png out.vbm")
    png_to_vbm(sys.argv[1], sys.argv[2])
