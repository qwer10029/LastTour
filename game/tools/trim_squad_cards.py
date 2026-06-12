"""Trim squad menu cards: remove edge-connected pure black, crop empty bands."""
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SQUAD_DIR = ROOT / "assets" / "menu" / "squad"

FILES = (
    SQUAD_DIR / "card_scavenger.png",
    SQUAD_DIR / "card_logistics.png",
)

# 与边缘连通、且为纯黑或全透明的像素会被去掉；卡片内部暗色阴影保留。
BLACK_MAX = 4
PAD = 0


def is_void_pixel(r: int, g: int, b: int, a: int) -> bool:
    if a < 8:
        return True
    return r <= BLACK_MAX and g <= BLACK_MAX and b <= BLACK_MAX


def strip_edge_void(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    w, h = rgba.size
    pixels = rgba.load()
    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        if 0 <= x < w and 0 <= y < h and not visited[y][x]:
            pr, pg, pb, pa = pixels[x, y]
            if is_void_pixel(pr, pg, pb, pa):
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
                if is_void_pixel(pr, pg, pb, pa):
                    visited[ny][nx] = True
                    q.append((nx, ny))
    return rgba


def trim_empty_bands(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    w, h = rgba.size
    pixels = rgba.load()

    def row_is_empty(y: int) -> bool:
        return all(is_void_pixel(*pixels[x, y]) for x in range(w))

    def col_is_empty(x: int, top: int, bottom: int) -> bool:
        return all(is_void_pixel(*pixels[x, y]) for y in range(top, bottom + 1))

    top = 0
    while top < h and row_is_empty(top):
        top += 1
    bottom = h - 1
    while bottom > top and row_is_empty(bottom):
        bottom -= 1
    if top > bottom:
        return rgba

    left = 0
    while left < w and col_is_empty(left, top, bottom):
        left += 1
    right = w - 1
    while right > left and col_is_empty(right, top, bottom):
        right -= 1
    return rgba.crop((left, top, right + 1, bottom + 1))


def crop_to_content(img: Image.Image, pad: int = PAD) -> Image.Image:
    bbox = img.getbbox()
    if bbox is None:
        return img
    left = max(0, bbox[0] - pad)
    top = max(0, bbox[1] - pad)
    right = min(img.width, bbox[2] + pad)
    bottom = min(img.height, bbox[3] + pad)
    return img.crop((left, top, right, bottom))


def process(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(path)
    before_size = path.stat().st_size
    with Image.open(path) as src:
        old_size = src.size
        img = strip_edge_void(src)
        img = trim_empty_bands(img)
        img = crop_to_content(img)
        img.save(path, format="PNG", optimize=True, compress_level=9)
    after_size = path.stat().st_size
    print(
        f"{path.name}: {old_size[0]}x{old_size[1]} -> {img.size[0]}x{img.size[1]}  "
        f"{before_size // 1024}KB -> {after_size // 1024}KB"
    )


def main() -> None:
    for path in FILES:
        process(path)


if __name__ == "__main__":
    main()
