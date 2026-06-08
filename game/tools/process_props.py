"""Remove checkerboard/field backgrounds and compress prop sprites."""
from __future__ import annotations

import os
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PROPS_DIR = ROOT / "assets" / "sprites" / "props"
ROAD_DIR = ROOT / "assets" / "tiles" / "road"

FILES: dict[Path, int] = {
    PROPS_DIR / "grass_clump.png": 128,
    PROPS_DIR / "rock_small.png": 128,
    PROPS_DIR / "rock_large.png": 192,
    PROPS_DIR / "dead_tree.png": 192,
    PROPS_DIR / "rubble_pile.png": 192,
    PROPS_DIR / "wreck_tank.png": 256,
    PROPS_DIR / "rubble_barricade.png": 256,
    ROAD_DIR / "road_crater.png": 256,
}


def is_background(r: int, g: int, b: int, a: int) -> bool:
    if a < 8:
        return True
    mx = max(r, g, b)
    mn = min(r, g, b)
    sat = (mx - mn) / 255.0
    lum = (r + g + b) / 3.0 / 255.0

    # Checkerboard whites / light grays
    if sat < 0.07 and lum > 0.42:
        return True
    # Mid checkerboard grays
    if sat < 0.06 and 0.22 < lum < 0.58:
        return True

    # Olive wasteland field used in some exports
    if 40 <= r <= 130 and 70 <= g <= 175 and 20 <= b <= 120 and g >= r and (g - b) > 8:
        if sat < 0.35:
            return True

    # Flat gray-green backdrop
    if abs(r - g) < 18 and abs(g - b) < 28 and 60 <= r <= 150 and lum < 0.55:
        if sat < 0.18:
            return True

    return False


def remove_background(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    w, h = rgba.size
    pixels = rgba.load()
    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def try_seed(x: int, y: int) -> None:
        if 0 <= x < w and 0 <= y < h and not visited[y][x]:
            pr, pg, pb, pa = pixels[x, y]
            if is_background(pr, pg, pb, pa):
                visited[y][x] = True
                q.append((x, y))

    for x in range(w):
        try_seed(x, 0)
        try_seed(x, h - 1)
    for y in range(h):
        try_seed(0, y)
        try_seed(w - 1, y)

    while q:
        x, y = q.popleft()
        pixels[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                pr, pg, pb, pa = pixels[nx, ny]
                if is_background(pr, pg, pb, pa):
                    visited[ny][nx] = True
                    q.append((nx, ny))

    return rgba


def crop_to_content(img: Image.Image, pad: int = 2) -> Image.Image:
    bbox = img.getbbox()
    if bbox is None:
        return img
    left = max(0, bbox[0] - pad)
    top = max(0, bbox[1] - pad)
    right = min(img.width, bbox[2] + pad)
    bottom = min(img.height, bbox[3] + pad)
    return img.crop((left, top, right, bottom))


def resize_to_max(img: Image.Image, max_side: int) -> Image.Image:
    w, h = img.size
    if max(w, h) <= max_side:
        return img
    scale = max_side / float(max(w, h))
    new_w = max(1, int(round(w * scale)))
    new_h = max(1, int(round(h * scale)))
    return img.resize((new_w, new_h), Image.Resampling.NEAREST)


def process(path: Path, max_side: int) -> None:
    if not path.exists():
        print(f"SKIP missing {path}")
        return
    before = path.stat().st_size
    img = Image.open(path)
    img = remove_background(img)
    img = crop_to_content(img)
    img = resize_to_max(img, max_side)
    img.save(path, format="PNG", optimize=True, compress_level=9)
    after = path.stat().st_size
    print(f"{path.name}: {img.size[0]}x{img.size[1]}  {before//1024}KB -> {after//1024}KB")


def main() -> None:
    for path, max_side in FILES.items():
        process(path, max_side)


if __name__ == "__main__":
    main()
