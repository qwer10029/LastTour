"""Import Mini DayZ style wilderness ground tile."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

SRC = Path(
    r"C:\Users\23022\.cursor\projects"
    r"\d-HuaweiMoveData-Users-23022-Desktop-home-Sophomore-second-semester-GirlsLastTour"
    r"\assets"
    r"\c__Users_23022_AppData_Roaming_Cursor_User_workspaceStorage_c8adbdc222027b2154ba0825704f6aa2_images_2026-06-08_22-27-51_Lumina_1-d532b4f5-0e26-4e20-9b84-ce964fe39e3e.png"
)
DST = Path(__file__).resolve().parents[1] / "assets" / "tiles" / "ground_wilderness.png"
TILE_SIZE = 256


def main() -> None:
    img = Image.open(SRC).convert("RGBA")
    if img.size != (TILE_SIZE, TILE_SIZE):
        img = img.resize((TILE_SIZE, TILE_SIZE), Image.Resampling.NEAREST)
    DST.parent.mkdir(parents=True, exist_ok=True)
    img.save(DST, format="PNG", optimize=True)
    print(f"ground_wilderness.png: {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main()
