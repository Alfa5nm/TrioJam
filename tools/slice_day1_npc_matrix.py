"""Split the authored Day 1 NPC sheet into its sixteen 4x4 grid cells."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


DEFAULT_SOURCE = Path(r"C:\Users\alfar\Pictures\Scene01\broadcast v2\Day1_NPC.png")
DEFAULT_OUTPUT = Path("assets/art/Day1 Scene 1/npcs")

# Narrative assignments supplied by the scene author. Cells not explicitly
# assigned remain coordinate-labelled so the pipeline does not invent a role.
CELL_NAMES = {
    (1, 1): "smoking-civilian",
    (1, 2): "occupation-protester-a",
    (1, 3): "occupation-protester-b",
    (1, 4): "occupation-protester-c",
    (2, 1): "seedless-representative-guard-a",
    (2, 2): "unassigned",
    (2, 3): "gossiping-gal-a",
    (2, 4): "gossiping-gal-b",
    (3, 1): "seedless-campaign-representative",
    (3, 2): "seedless-representative-guard-b",
    (3, 3): "unassigned",
    (3, 4): "unassigned",
    (4, 1): "anti-seedless-protester-a",
    (4, 2): "anti-seedless-protester-b",
    (4, 3): "anti-seedless-protester-c",
    (4, 4): "anti-seedless-protester-d",
}


def slice_sheet(source: Path, output_dir: Path) -> None:
    sheet = Image.open(source).convert("RGBA")
    width, height = sheet.size
    if width % 4 or height % 4:
        raise ValueError(f"Sheet must divide evenly into 4x4 cells, got {sheet.size}")

    cell_width = width // 4
    cell_height = height // 4
    output_dir.mkdir(parents=True, exist_ok=True)
    sheet.save(output_dir / "day1-npc-4x4-source.png", optimize=True)

    manifest = {
        "source": "day1-npc-4x4-source.png",
        "matrix": {"rows": 4, "columns": 4},
        "cell_size": [cell_width, cell_height],
        "sprites": [],
    }

    for row in range(1, 5):
        for column in range(1, 5):
            left = (column - 1) * cell_width
            top = (row - 1) * cell_height
            cell = sheet.crop((left, top, left + cell_width, top + cell_height))
            role = CELL_NAMES[(row, column)]
            filename = f"r{row}c{column}-{role}.png"
            cell.save(output_dir / filename, optimize=True)
            alpha_bbox = cell.getchannel("A").getbbox()
            manifest["sprites"].append(
                {
                    "row": row,
                    "column": column,
                    "role": role,
                    "file": filename,
                    "content_bounds": list(alpha_bbox) if alpha_bbox else None,
                }
            )
            print(f"{row},{column}: {filename} bounds={alpha_bbox}")

    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    slice_sheet(args.source, args.output)


if __name__ == "__main__":
    main()
