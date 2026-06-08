"""Import assets from ../new pictures, optionally key background, crop and compress."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

from process_props import crop_to_content, process, remove_background, resize_to_max

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
SRC_DIR = REPO / "new pictures"
PROPS_DIR = ROOT / "assets" / "sprites" / "props"
ROAD_DIR = ROOT / "assets" / "tiles" / "road"

# source filename -> (destination, max_side, already_keyed)
IMPORTS: list[tuple[str, Path, int, bool]] = [
    ("草.png", PROPS_DIR / "grass_clump.png", 72, True),
    ("小石头.jpg", PROPS_DIR / "rock_small.png", 80, False),
    ("大石头.jpg", PROPS_DIR / "rock_large.png", 140, False),
    ("枯树.jpg", PROPS_DIR / "dead_tree.png", 240, False),
    ("废墟.jpg", PROPS_DIR / "rubble_pile.png", 160, False),
    ("报废坦克.jpg", PROPS_DIR / "wreck_tank.png", 256, False),
    ("废弃工事.jpg", PROPS_DIR / "rubble_barricade.png", 256, False),
    ("弹坑.jpg", ROAD_DIR / "road_crater.png", 256, False),
]


def process_prekeyed(path: Path, max_side: int) -> None:
    before = path.stat().st_size
    img = Image.open(path).convert("RGBA")
    img = crop_to_content(img, pad=1)
    img = resize_to_max(img, max_side)
    img.save(path, format="PNG", optimize=True, compress_level=9)
    after = path.stat().st_size
    print(f"{path.name}: {img.size[0]}x{img.size[1]}  {before // 1024}KB -> {after // 1024}KB (pre-keyed)")


def import_one(src_name: str, dst: Path, max_side: int, prekeyed: bool) -> None:
    src = SRC_DIR / src_name
    if not src.exists():
        print(f"MISSING {src}")
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    img = Image.open(src)
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    img.save(dst, format="PNG")
    if prekeyed:
        process_prekeyed(dst, max_side)
    else:
        process(dst, max_side)


def main() -> None:
    for src_name, dst, max_side, prekeyed in IMPORTS:
        import_one(src_name, dst, max_side, prekeyed)


if __name__ == "__main__":
    main()
