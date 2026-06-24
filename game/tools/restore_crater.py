"""Restore crater: strip outer checkerboard only, keep dark hole opaque."""
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

SRC = Path(__file__).resolve().parents[2] / "assets" / "reference" / "弹坑.jpg"
DST = Path(__file__).resolve().parents[1] / "assets" / "tiles" / "road" / "road_crater.png"
MAX_SIDE = 256
HOLE_FILL = (24, 20, 18, 255)


def is_outer_checkerboard(r: int, g: int, b: int, a: int) -> bool:
    if a < 8:
        return True
    mx = max(r, g, b)
    mn = min(r, g, b)
    sat = (mx - mn) / 255.0
    lum = (r + g + b) / 3.0 / 255.0
    return sat < 0.08 and lum > 0.42


def strip_outer_background(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    w, h = rgba.size
    pixels = rgba.load()
    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        if 0 <= x < w and 0 <= y < h and not visited[y][x]:
            pr, pg, pb, pa = pixels[x, y]
            if is_outer_checkerboard(pr, pg, pb, pa):
                visited[y][x] = True
                q.append((x, y))

    for x in range(w):
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):
        seed(0, y)
        seed(w - 1, y)

    while q:
        x, y = q.popleft()
        pixels[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                pr, pg, pb, pa = pixels[nx, ny]
                if is_outer_checkerboard(pr, pg, pb, pa):
                    visited[ny][nx] = True
                    q.append((nx, ny))
    return rgba


def fill_transparent_hole(img: Image.Image) -> Image.Image:
    pixels = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = pixels[x, y]
            if a < 160:
                pixels[x, y] = HOLE_FILL
    return img


def crop_to_content(img: Image.Image, pad: int = 2) -> Image.Image:
    bbox = img.getbbox()
    if bbox is None:
        return img
    return img.crop(
        (
            max(0, bbox[0] - pad),
            max(0, bbox[1] - pad),
            min(img.width, bbox[2] + pad),
            min(img.height, bbox[3] + pad),
        )
    )


def resize_to_max(img: Image.Image, max_side: int) -> Image.Image:
    w, h = img.size
    if max(w, h) <= max_side:
        return img
    scale = max_side / float(max(w, h))
    return img.resize(
        (max(1, int(round(w * scale))), max(1, int(round(h * scale)))),
        Image.Resampling.NEAREST,
    )


def main() -> None:
    before = DST.stat().st_size if DST.exists() else 0
    img = Image.open(SRC)
    img = strip_outer_background(img)
    img = fill_transparent_hole(img)
    img = crop_to_content(img)
    img = resize_to_max(img, MAX_SIDE)
    DST.parent.mkdir(parents=True, exist_ok=True)
    img.save(DST, format="PNG", optimize=True, compress_level=9)
    after = DST.stat().st_size
    print(f"road_crater.png: {img.size[0]}x{img.size[1]}  {before // 1024}KB -> {after // 1024}KB (opaque hole)")


if __name__ == "__main__":
    main()
