#!/usr/bin/env python3
import argparse
import ctypes
import ctypes.util
import os
import struct
import subprocess
import sys
import tempfile


class XAutomationError(RuntimeError):
    pass


def _load_lib(name: str):
    path = ctypes.util.find_library(name)
    if not path:
        raise XAutomationError(f"missing shared library: {name}")
    return ctypes.CDLL(path)


_X11 = _load_lib("X11")
_XTST = _load_lib("Xtst")

_X11.XOpenDisplay.argtypes = [ctypes.c_char_p]
_X11.XOpenDisplay.restype = ctypes.c_void_p
_X11.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
_X11.XDefaultRootWindow.restype = ctypes.c_ulong
_X11.XFlush.argtypes = [ctypes.c_void_p]
_X11.XFlush.restype = ctypes.c_int
_X11.XCloseDisplay.argtypes = [ctypes.c_void_p]
_X11.XCloseDisplay.restype = ctypes.c_int

_XTST.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
_XTST.XTestFakeKeyEvent.restype = ctypes.c_int
_XTST.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
_XTST.XTestFakeButtonEvent.restype = ctypes.c_int
_XTST.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
_XTST.XTestFakeMotionEvent.restype = ctypes.c_int
_XTST.XTestQueryExtension.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int)]
_XTST.XTestQueryExtension.restype = ctypes.c_int


def open_display():
    display_name = os.environ.get("DISPLAY")
    disp = _X11.XOpenDisplay(display_name.encode() if display_name else None)
    if not disp:
        raise XAutomationError(f"could not open display {display_name!r}")
    return disp


def keycode_for(display, keysym: int) -> int:
    _X11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
    _X11.XKeysymToKeycode.restype = ctypes.c_uint
    code = int(_X11.XKeysymToKeycode(display, keysym))
    if code == 0:
        raise XAutomationError(f"no keycode for keysym {keysym}")
    return code


def query_xtest(display):
    a = ctypes.c_int()
    b = ctypes.c_int()
    c = ctypes.c_int()
    d = ctypes.c_int()
    if not _XTST.XTestQueryExtension(display, ctypes.byref(a), ctypes.byref(b), ctypes.byref(c), ctypes.byref(d)):
        raise XAutomationError("XTest extension is not available")


def press_key(display, keycode: int):
    _XTST.XTestFakeKeyEvent(display, keycode, 1, 0)
    _XTST.XTestFakeKeyEvent(display, keycode, 0, 0)


def click(display, x: int, y: int, button: int = 1):
    _XTST.XTestFakeMotionEvent(display, -1, x, y, 0)
    _XTST.XTestFakeButtonEvent(display, button, 1, 0)
    _XTST.XTestFakeButtonEvent(display, button, 0, 0)


def screenshot_xwd(out_path: str):
    subprocess.run(["xwd", "-root", "-silent", "-out", out_path], check=True)


def xwd_to_png(xwd_path: str, png_path: str):
    with open(xwd_path, "rb") as f:
        data = f.read()
    if len(data) < 100:
        raise XAutomationError("xwd file too small")

    header_fmt = ">26I"
    header = struct.unpack(header_fmt, data[:104])
    header_size = header[0]
    file_version = header[1]
    pixmap_format = header[6]
    pixmap_depth = header[7]
    width = header[10]
    height = header[11]
    byte_order = header[18]
    bits_per_pixel = header[17]
    bytes_per_line = header[16]
    ncolors = header[20]

    if file_version != 7:
        raise XAutomationError(f"unsupported xwd version: {file_version}")
    if pixmap_format != 2:
        raise XAutomationError("only ZPixmap xwd screenshots are supported")

    name_size = header[4]
    start = header_size + name_size
    start += (4 - (start % 4)) % 4
    cmap_size = ncolors * 12
    start += cmap_size

    pixel_data = data[start:]
    if len(pixel_data) < height * bytes_per_line:
        raise XAutomationError("truncated xwd pixel data")

    if bits_per_pixel != 32:
        raise XAutomationError(f"unsupported bits_per_pixel: {bits_per_pixel}")

    # Best-effort conversion for the common 32bpp X11 root capture format.
    rows = []
    for y in range(height):
        row = pixel_data[y * bytes_per_line:(y + 1) * bytes_per_line]
        pixels = []
        for x in range(width):
            px = row[x * 4:(x + 1) * 4]
            if byte_order == 0:
                b, g, r, a = px[0], px[1], px[2], px[3]
            else:
                a, r, g, b = px[0], px[1], px[2], px[3]
            pixels.append(bytes([r, g, b, 255]))
        rows.append(b"".join(pixels))

    raw = b"".join(b"\x00" + row for row in rows)
    import zlib

    def png_chunk(tag: bytes, chunk_data: bytes) -> bytes:
        return struct.pack(">I", len(chunk_data)) + tag + chunk_data + struct.pack(">I", zlib.crc32(tag + chunk_data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(raw, 9)
    png = b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", ihdr) + png_chunk(b"IDAT", idat) + png_chunk(b"IEND", b"")
    with open(png_path, "wb") as f:
        f.write(png)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", action="append", default=[], help="press a keysym name or alias like Return, space, 1")
    ap.add_argument("--click", nargs=2, type=int, action="append", default=[], metavar=("X", "Y"))
    ap.add_argument("--sleep", type=float, default=0.0)
    ap.add_argument("--screenshot", metavar="PNG")
    args = ap.parse_args()

    display = open_display()
    query_xtest(display)

    keysym_map = {
        "Return": 0xFF0D,
        "Enter": 0xFF0D,
        "space": 0x0020,
        "Escape": 0xFF1B,
        "Tab": 0xFF09,
        "Up": 0xFF52,
        "Down": 0xFF54,
        "Left": 0xFF51,
        "Right": 0xFF53,
        "1": 0x0031,
        "2": 0x0032,
        "3": 0x0033,
        "4": 0x0034,
        "5": 0x0035,
        "6": 0x0036,
        "7": 0x0037,
        "8": 0x0038,
        "9": 0x0039,
        "a": 0x0061,
        "b": 0x0062,
        "c": 0x0063,
        "d": 0x0064,
        "e": 0x0065,
        "f": 0x0066,
        "j": 0x006A,
        "m": 0x006D,
        "p": 0x0070,
        "q": 0x0071,
        "r": 0x0072,
        "w": 0x0077,
        "s": 0x0073,
    }

    for key in args.key:
        if len(key) == 1:
            keysym = ord(key)
        else:
            keysym = keysym_map.get(key, None)
            if keysym is None:
                raise SystemExit(f"unknown key alias: {key}")
        keycode = keycode_for(display, keysym)
        press_key(display, keycode)
        _X11.XFlush(display)

    for x, y in args.click:
        click(display, x, y)
        _X11.XFlush(display)

    if args.sleep > 0:
        import time

        time.sleep(args.sleep)

    if args.screenshot:
        with tempfile.NamedTemporaryFile(suffix=".xwd", delete=False) as tmp:
            xwd_path = tmp.name
        try:
            screenshot_xwd(xwd_path)
            xwd_to_png(xwd_path, args.screenshot)
        finally:
            try:
                os.unlink(xwd_path)
            except OSError:
                pass

    _X11.XCloseDisplay(display)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
