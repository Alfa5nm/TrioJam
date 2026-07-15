"""Register an AI-authored 6x3 character sheet to stable Godot pivots."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


TARGET_CELL = (384, 512)
TARGET_HEAD_X = 190
TARGET_FOOT_Y = 470


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > 16 else 0).getbbox()
    if bbox is None:
        raise ValueError("Frame contains no visible pixels")
    return bbox


def head_center_x(image: Image.Image, bbox: tuple[int, int, int, int]) -> int:
    left, top, right, bottom = bbox
    head_bottom = top + max(12, int((bottom - top) * 0.22))
    alpha = image.getchannel("A")
    weighted_x: list[int] = []
    for y in range(top, min(head_bottom, image.height)):
        for x in range(left, right):
            if alpha.getpixel((x, y)) > 32:
                weighted_x.append(x)
    if not weighted_x:
        return (left + right) // 2
    return round(sum(weighted_x) / len(weighted_x))


def normalize(source: Path, output: Path, cols: int, rows: int) -> None:
    sheet = Image.open(source).convert("RGBA")
    x_bounds = [round(index * sheet.width / cols) for index in range(cols + 1)]
    y_bounds = [round(index * sheet.height / rows) for index in range(rows + 1)]
    target = Image.new("RGBA", (TARGET_CELL[0] * cols, TARGET_CELL[1] * rows))

    for row in range(rows):
        for column in range(cols):
            frame = sheet.crop(
                (x_bounds[column], y_bounds[row], x_bounds[column + 1], y_bounds[row + 1])
            )
            bbox = alpha_bbox(frame)
            head_x = head_center_x(frame, bbox)
            foot_y = bbox[3] - 1
            offset_x = TARGET_HEAD_X - head_x
            offset_y = TARGET_FOOT_Y - foot_y
            cell = Image.new("RGBA", TARGET_CELL)
            cell.alpha_composite(frame, (offset_x, offset_y))
            target.alpha_composite(cell, (column * TARGET_CELL[0], row * TARGET_CELL[1]))

    output.parent.mkdir(parents=True, exist_ok=True)
    target.save(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--cols", type=int, default=6)
    parser.add_argument("--rows", type=int, default=3)
    args = parser.parse_args()
    normalize(args.source, args.output, args.cols, args.rows)


if __name__ == "__main__":
    main()
