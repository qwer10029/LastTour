"""Shift wilderness ground tile to post-war scorched earth palette."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

TARGET = (
    Path(__file__).resolve().parents[1] / "assets" / "tiles" / "ground_wilderness.png"
)


def scorch(r: int, g: int, b: int, a: int) -> tuple[int, int, int, int]:
    if a < 8:
        return 0, 0, 0, 0
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    nr = r * 0.28 + lum * 0.58 + 14.0
    ng = g * 0.14 + lum * 0.36 + 6.0
    nb = b * 0.18 + lum * 0.34 + 4.0
    nr *= 0.58
    ng *= 0.50
    nb *= 0.48
    nr = min(255, int(nr + 16))
    ng = min(255, int(ng * 0.88))
    nb = min(255, int(nb * 0.82))
    return nr, ng, nb, a


def main() -> None:
    img = Image.open(TARGET).convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            px[x, y] = scorch(*px[x, y])
    img.save(TARGET, format="PNG", optimize=True)
    print(f"scorched: {TARGET}")


if __name__ == "__main__":
    main()
