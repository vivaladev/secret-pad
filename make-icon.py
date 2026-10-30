#!/usr/bin/python3
"""Pixel icon: a key behind bars. Nearest-neighbor scaled into a macOS iconset."""

import struct
import subprocess
import zlib
from pathlib import Path

SIZE = 64
BG = (18, 18, 20)
GREEN = (92, 181, 86)
GREEN_DARK = (46, 110, 42)
BAR = (36, 38, 44)
BAR_HI = (176, 178, 184)
BAR_LO = (12, 12, 14)

pixels = [[BG for _ in range(SIZE)] for _ in range(SIZE)]


def put(x, y, color):
    if 0 <= x < SIZE and 0 <= y < SIZE:
        pixels[y][x] = color


def key():
    cx, cy, outer, inner = 22, 32, 14, 5
    for y in range(SIZE):
        for x in range(SIZE):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if inner * inner < d2 <= outer * outer:
                put(x, y, GREEN_DARK if d2 > (outer - 2) ** 2 else GREEN)
    for y in range(29, 36):
        for x in range(34, 58):
            put(x, y, GREEN if 30 <= y <= 34 else GREEN_DARK)
    for y in range(35, 46):
        for x in range(48, 53):
            put(x, y, GREEN)
    for y in range(35, 42):
        for x in range(55, 59):
            put(x, y, GREEN)


def bars():
    for x0 in (8, 24, 40, 56):
        for y in range(6, 58):
            put(x0, y, BAR_HI)
            put(x0 + 1, y, BAR)
            put(x0 + 2, y, BAR)
            put(x0 + 3, y, BAR_LO)


def png_bytes(width, height, rows):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + bytes(channel for pixel in row for channel in pixel) for row in rows)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def scale(factor):
    out = []
    for row in pixels:
        stretched = [pixel for pixel in row for _ in range(factor)]
        for _ in range(factor):
            out.append(stretched)
    return out


def main():
    key()
    bars()
    root = Path(__file__).resolve().parent
    iconset = root / "SecretPad.iconset"
    iconset.mkdir(exist_ok=True)
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    master = {16: None}
    for name, side in sizes.items():
        if side < SIZE:
            step = SIZE // side
            rows = [[pixels[y * step][x * step] for x in range(side)] for y in range(side)]
        else:
            rows = scale(side // SIZE)
        (iconset / name).write_bytes(png_bytes(side, side, rows))
    preview = root / "icon-preview.png"
    preview.write_bytes(png_bytes(512, 512, scale(8)))
    subprocess.check_call(["iconutil", "-c", "icns", str(iconset), "-o", str(root / "SecretPad.icns")])
    print(preview)


if __name__ == "__main__":
    main()
