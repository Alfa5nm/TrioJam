"""Normalize the generated Day 1 protest atlas into Godot animation strips.

The source is a 4x4 chroma-keyed/alpha atlas whose generated dimensions are not
guaranteed to divide cleanly.  This exporter uses proportional cell boundaries,
then resamples every frame to the project's fixed 512x512 animation cell.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/art/Day1 Scene 1/protest"
ACTORS = ("sign_male", "fist_chanter", "sign_female", "megaphone_worker")
SOURCES = {
    "chant": OUTPUT / "source/day1-protest-atlas-v1-rgba.png",
    "panic": OUTPUT / "source/day1-protest-panic-atlas-v1-rgba.png",
}
CELL = 512


def proportional_edge(index: int, extent: int) -> int:
    return round(index * extent / 4.0)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for action, source_path in SOURCES.items():
        source = Image.open(source_path).convert("RGBA")
        for row, actor in enumerate(ACTORS):
            strip = Image.new("RGBA", (CELL * 4, CELL), (0, 0, 0, 0))
            top = proportional_edge(row, source.height)
            bottom = proportional_edge(row + 1, source.height)
            for column in range(4):
                left = proportional_edge(column, source.width)
                right = proportional_edge(column + 1, source.width)
                frame = source.crop((left, top, right, bottom))
                frame = frame.resize((CELL, CELL), Image.Resampling.LANCZOS)
                strip.alpha_composite(frame, (column * CELL, 0))
            strip.save(OUTPUT / f"{actor}-{action}-v1.png", optimize=True)


if __name__ == "__main__":
    main()
