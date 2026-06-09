"""Import AI-generated snow ground tile into game/assets/tiles/ground_snow.png."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

DST = Path(__file__).resolve().parents[1] / "assets" / "tiles" / "ground_snow.png"
TILE_SIZE = 256


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: py -3 game/tools/import_ground_snow.py <source_image.png>")
        raise SystemExit(1)
    src = Path(sys.argv[1]).expanduser().resolve()
    img = Image.open(src).convert("RGBA")
    if img.size != (TILE_SIZE, TILE_SIZE):
        img = img.resize((TILE_SIZE, TILE_SIZE), Image.Resampling.LANCZOS)
    DST.parent.mkdir(parents=True, exist_ok=True)
    img.save(DST, format="PNG", optimize=True)
    print(f"ground_snow.png: {img.size[0]}x{img.size[1]} <- {src}")


if __name__ == "__main__":
    main()
