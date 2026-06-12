"""Bake alpha for player foot sprites: remove edge-connected flat grey only."""
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPRITES_DIR = ROOT / "assets" / "sprites"

FILES = (
    SPRITES_DIR / "player_foot_walk_all.png",
    SPRITES_DIR / "player_foot_walk_up.png",
    SPRITES_DIR / "player_foot.png",
)

# 仅去掉与画布边缘连通的纯灰底；头盔/头发等前景色不会被误抠。
GREY_TOLERANCE = 14


def _median(values: list[int]) -> int:
    ordered = sorted(values)
    return ordered[len(ordered) // 2]


def _background_refs(img: Image.Image) -> tuple[int, int, int]:
    rgba = img.convert("RGBA")
    w, h = rgba.size
    pixels = rgba.load()
    rs: list[int] = []
    gs: list[int] = []
    bs: list[int] = []
    for x, y in (
        (0, 0),
        (w - 1, 0),
        (0, h - 1),
        (w - 1, h - 1),
        (w // 2, 0),
        (w // 2, h - 1),
    ):
        r, g, b, a = pixels[x, y]
        if a < 8:
            continue
        rs.append(r)
        gs.append(g)
        bs.append(b)
    if not rs:
        return (157, 157, 157)
    return (_median(rs), _median(gs), _median(bs))


def _matches_flat_grey(r: int, g: int, b: int, a: int, ref: tuple[int, int, int]) -> bool:
    if a < 8:
        return True
    return (
        abs(r - ref[0]) <= GREY_TOLERANCE
        and abs(g - ref[1]) <= GREY_TOLERANCE
        and abs(b - ref[2]) <= GREY_TOLERANCE
    )


def strip_edge_grey(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    w, h = rgba.size
    pixels = rgba.load()
    ref = _background_refs(rgba)
    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        if 0 <= x < w and 0 <= y < h and not visited[y][x]:
            pr, pg, pb, pa = pixels[x, y]
            if _matches_flat_grey(pr, pg, pb, pa, ref):
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
                if _matches_flat_grey(pr, pg, pb, pa, ref):
                    visited[ny][nx] = True
                    q.append((nx, ny))
    return rgba


def _helmet_pixels_ok(img: Image.Image) -> bool:
    rgba = img.convert("RGBA")
    w, h = rgba.size
    pixels = rgba.load()
    frame_w = max(1, w // 8)
    # 帧 0 顶部头盔区域应仍有不透明像素
    opaque = 0
    for y in range(8, 36):
        for x in range(frame_w // 2 - 24, frame_w // 2 + 24):
            if 0 <= x < w and pixels[x, y][3] > 200:
                opaque += 1
    return opaque >= 8


def process(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(path)
    with Image.open(path) as src:
        old_size = src.size
        ref = _background_refs(src)
        img = strip_edge_grey(src)
        if not _helmet_pixels_ok(img):
            raise RuntimeError(f"{path.name}: helmet/top pixels were removed; aborting")
        img.save(path, format="PNG", optimize=True, compress_level=9)
    print(f"{path.name}: {old_size[0]}x{old_size[1]} bg={ref} -> baked alpha")


def main() -> None:
    for path in FILES:
        process(path)


if __name__ == "__main__":
    main()
