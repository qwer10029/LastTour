"""Re-process scrap.png: remove only outer backdrop, keep internal dark pixels."""
from __future__ import annotations

import subprocess
import sys
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SCRAP_PATH = ROOT / "assets" / "sprites" / "loot" / "scrap.png"
TARGET = 64


def load_source() -> Image.Image:
    if SCRAP_PATH.exists():
        img = Image.open(SCRAP_PATH).convert("RGBA")
        # Already processed: no opaque dark pixels left. Try git original.
        px = img.load()
        dark_opaque = sum(
            1
            for y in range(img.height)
            for x in range(img.width)
            if px[x, y][3] >= 128 and max(px[x, y][:3]) <= 20
        )
        if dark_opaque > 0:
            return img
    repo = ROOT.parent
    raw = subprocess.check_output(
        ["git", "show", "ba387df:game/assets/sprites/loot/scrap.png"],
        cwd=repo,
    )
    from io import BytesIO

    return Image.open(BytesIO(raw)).convert("RGBA")


def is_backdrop_black(r: int, g: int, b: int, a: int) -> bool:
    if a < 8:
        return True
    # Only flood-fill near-pure backdrop black, not object shadow/detail.
    return r <= 4 and g <= 4 and b <= 4


def strip_outer_black(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    w, h = rgba.size
    pixels = rgba.load()
    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        if 0 <= x < w and 0 <= y < h and not visited[y][x]:
            pr, pg, pb, pa = pixels[x, y]
            if is_backdrop_black(pr, pg, pb, pa):
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
                if is_backdrop_black(pr, pg, pb, pa):
                    visited[ny][nx] = True
                    q.append((nx, ny))
    return rgba


def fit_square(img: Image.Image, size: int) -> Image.Image:
    bbox = img.getbbox()
    if bbox is None:
        return img
    cropped = img.crop(bbox)
    cw, ch = cropped.size
    scale = size / float(max(cw, ch))
    nw = max(1, int(round(cw * scale)))
    nh = max(1, int(round(ch * scale)))
    resized = cropped.resize((nw, nh), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ox = (size - nw) // 2
    oy = (size - nh) // 2
    canvas.paste(resized, (ox, oy), resized)
    return canvas


def main() -> None:
    src = load_source()
    out = fit_square(strip_outer_black(src), TARGET)
    px = out.load()
    transparent = sum(1 for y in range(out.height) for x in range(out.width) if px[x, y][3] < 128)
    dark_opaque = sum(
        1
        for y in range(out.height)
        for x in range(out.width)
        if px[x, y][3] >= 128 and max(px[x, y][:3]) <= 20
    )
    out.save(SCRAP_PATH, format="PNG", optimize=True)
    print(f"saved {SCRAP_PATH.name}: transparent={transparent} dark_opaque={dark_opaque}")


if __name__ == "__main__":
    main()
