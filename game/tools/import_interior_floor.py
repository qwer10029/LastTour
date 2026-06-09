"""Import interior floor tile into game/assets/tiles/interior/floor.png."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

DST = Path(__file__).resolve().parents[1] / "assets" / "tiles" / "interior" / "floor.png"
TILE_SIZE = 128


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: py -3 game/tools/import_interior_floor.py <source_image.png>")
        raise SystemExit(1)
    src = Path(sys.argv[1]).expanduser().resolve()
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    if w != h:
        side = min(w, h)
        left = (w - side) // 2
        top = (h - side) // 2
        img = img.crop((left, top, left + side, top + side))
    if img.size != (TILE_SIZE, TILE_SIZE):
        img = img.resize((TILE_SIZE, TILE_SIZE), Image.Resampling.LANCZOS)
    DST.parent.mkdir(parents=True, exist_ok=True)
    img.save(DST, format="PNG", optimize=True)
    print(f"floor.png: {img.size[0]}x{img.size[1]} <- {src}")


if __name__ == "__main__":
    main()
