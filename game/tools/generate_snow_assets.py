"""Generate snow overworld tiles for layer 3.

Outputs:
  assets/tiles/ground_snow.png          — seamless 256x256 snow field tile
  assets/tiles/road_snow/*.png          — snow-tinted road pieces (derived from road/)

Run from repo root or game/:
  python game/tools/generate_snow_assets.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

GAME_ROOT = Path(__file__).resolve().parents[1]
TILE_SIZE = 256
ROAD_NAMES = [
    "road_ns_segment.png",
    "road_ew_segment.png",
    "road_cross.png",
    "road_corner.png",
    "road_t.png",
    "road_crater.png",
]


def _hash_noise(x: float, y: float, seed: int = 0) -> float:
    return (math.sin(x * 12.9898 + y * 78.233 + seed * 43.719) * 43758.5453) % 1.0


def generate_ground_snow(path: Path) -> None:
    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE))
    px = img.load()
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            n1 = _hash_noise(x * 0.09, y * 0.09, 11)
            n2 = _hash_noise(x * 0.21, y * 0.21, 29)
            n3 = _hash_noise(x * 0.04, y * 0.04, 7)
            drift = 0.5 + 0.5 * math.sin((x + y) * 0.035 + n2 * 2.4)
            base = 228 + int(n1 * 18 + n3 * 10 + drift * 8)
            blue = 236 + int(n2 * 12)
            r = min(255, base + int(n3 * 6))
            g = min(255, base + int(n1 * 4))
            b = min(255, blue)
            # 轻微压暗条纹模拟被风吹过的雪面纹理
            wind = 0.92 + 0.08 * math.sin(x * 0.08 + y * 0.03)
            r = int(r * wind)
            g = int(g * wind)
            b = int(b * wind)
            px[x, y] = (r, g, b, 255)

    # 零星雪丘高光
    draw = ImageDraw.Draw(img)
    rng = random.Random(20260608)
    for _ in range(42):
        cx = rng.randint(0, TILE_SIZE - 1)
        cy = rng.randint(0, TILE_SIZE - 1)
        rad = rng.randint(6, 22)
        shade = rng.randint(238, 252)
        draw.ellipse(
            (cx - rad, cy - rad, cx + rad, cy + rad),
            fill=(shade, shade, min(255, shade + 6), 255),
        )
    img = img.filter(ImageFilter.GaussianBlur(radius=0.6))
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)
    print(f"wrote {path} ({TILE_SIZE}x{TILE_SIZE})")


def _is_road_background_pixel(r: int, g: int, b: int, a: int) -> bool:
    """与 art_asset_loader.apply_road_background_key 一致，并覆盖棋盘格深灰格。"""
    if a <= 0:
        return True
    max_c = max(r, g, b)
    min_c = min(r, g, b)
    lum = (r + g + b) / 3.0
    sat = max_c - min_c
    neutral = abs(r - g) <= 9 and abs(g - b) <= 9
    if r >= 235 and g >= 235 and b >= 235:
        return True
    if neutral and sat <= 18 and lum >= 82:
        return True
    if neutral and sat <= 18 and lum <= 48:
        return True
    if b >= 200 and r >= 175 and g >= 175 and (b - r) >= 8 and (b - g) >= 8:
        return True
    return False


def _snow_tint_road_pixel(r: int, g: int, b: int, a: int) -> tuple[int, int, int, int]:
    if _is_road_background_pixel(r, g, b, a):
        return (0, 0, 0, 0)
    lum = (r + g + b) / 3.0
    if lum >= 120:
        # 路面：冷灰沥青，略覆薄雪
        nr = int(150 + (r - 120) * 0.35 + 40)
        ng = int(158 + (g - 120) * 0.35 + 44)
        nb = int(172 + (b - 120) * 0.35 + 52)
    elif lum >= 55:
        # 路缘/脏边：积雪堆
        t = (lum - 55) / 65.0
        nr = int(210 + t * 20)
        ng = int(214 + t * 18)
        nb = int(224 + t * 16)
    else:
        # 裂缝/深痕：深蓝灰
        nr = int(r * 0.55 + 70)
        ng = int(g * 0.55 + 78)
        nb = int(b * 0.55 + 92)
    return (min(255, nr), min(255, ng), min(255, nb), a)


def generate_snow_road_variant(src: Path, dst: Path) -> None:
    img = Image.open(src).convert("RGBA")
    out = Image.new("RGBA", img.size)
    spx = img.load()
    opx = out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = spx[x, y]
            opx[x, y] = _snow_tint_road_pixel(r, g, b, a)
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, format="PNG", optimize=True)
    print(f"wrote {dst.name}")


def main() -> None:
    generate_ground_snow(GAME_ROOT / "assets" / "tiles" / "ground_snow.png")
    road_src = GAME_ROOT / "assets" / "tiles" / "road"
    road_dst = GAME_ROOT / "assets" / "tiles" / "road_snow"
    for name in ROAD_NAMES:
        src = road_src / name
        if src.exists():
            generate_snow_road_variant(src, road_dst / name)
        else:
            print(f"skip missing {src}")


if __name__ == "__main__":
    main()
