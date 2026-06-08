"""Import loot icons: strip outer black backdrop, keep enclosed holes."""
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LOOT_DIR = ROOT / "assets" / "sprites" / "loot"
CURSOR_ASSETS = Path(
    r"C:\Users\23022\.cursor\projects"
    r"\d-HuaweiMoveData-Users-23022-Desktop-home-Sophomore-second-semester-GirlsLastTour"
    r"\assets"
)

IMPORTS = {
    CURSOR_ASSETS
    / "c__Users_23022_AppData_Roaming_Cursor_User_workspaceStorage_c8adbdc222027b2154ba0825704f6aa2_images___-f3000c00-7457-446e-802f-875fd4331c9c.png": LOOT_DIR
    / "parts.png",
    CURSOR_ASSETS
    / "c__Users_23022_AppData_Roaming_Cursor_User_workspaceStorage_c8adbdc222027b2154ba0825704f6aa2_images___-567b2f62-b019-49aa-9502-4b314ed888ee.png": LOOT_DIR
    / "scrap.png",
}

TARGET = 64


def is_outer_black(r: int, g: int, b: int, a: int) -> bool:
    if a < 8:
        return True
    return r <= 20 and g <= 20 and b <= 20


def strip_outer_black(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    w, h = rgba.size
    pixels = rgba.load()
    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        if 0 <= x < w and 0 <= y < h and not visited[y][x]:
            pr, pg, pb, pa = pixels[x, y]
            if is_outer_black(pr, pg, pb, pa):
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
                if is_outer_black(pr, pg, pb, pa):
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
    for src, dst in IMPORTS.items():
        if not src.exists():
            raise FileNotFoundError(src)
        img = Image.open(src)
        img = strip_outer_black(img)
        img = fit_square(img, TARGET)
        dst.parent.mkdir(parents=True, exist_ok=True)
        img.save(dst, format="PNG", optimize=True)
        print(f"{dst.name}: {img.size[0]}x{img.size[1]}  from {src.name}")


if __name__ == "__main__":
    main()
