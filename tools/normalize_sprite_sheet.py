"""Register AI-authored character sheets to stable Godot pivots."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


DEFAULT_TARGET_CELL = (384, 512)
DEFAULT_TARGET_HEAD_X = 190
DEFAULT_TARGET_FOOT_Y = 470


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


def keep_largest_component(image: Image.Image) -> Image.Image:
    """Remove fragments that spill into a neighboring generated frame."""
    alpha = image.getchannel("A")
    width, height = image.size
    occupied = bytearray(1 if value > 32 else 0 for value in alpha.get_flattened_data())
    visited = bytearray(width * height)
    largest: list[int] = []

    for start, is_occupied in enumerate(occupied):
        if not is_occupied or visited[start]:
            continue
        visited[start] = 1
        queue = deque([start])
        component: list[int] = []
        while queue:
            index = queue.pop()
            component.append(index)
            x = index % width
            y = index // width
            neighbors = []
            if x:
                neighbors.append(index - 1)
            if x + 1 < width:
                neighbors.append(index + 1)
            if y:
                neighbors.append(index - width)
            if y + 1 < height:
                neighbors.append(index + width)
            for neighbor in neighbors:
                if occupied[neighbor] and not visited[neighbor]:
                    visited[neighbor] = 1
                    queue.append(neighbor)
        if len(component) > len(largest):
            largest = component

    if not largest:
        raise ValueError("Frame contains no connected subject")
    mask_data = bytearray(width * height)
    for index in largest:
        mask_data[index] = 255
    mask = Image.frombytes("L", image.size, bytes(mask_data))
    cleaned = Image.new("RGBA", image.size)
    cleaned.paste(image, mask=mask)
    return cleaned


def normalize(
    source: Path,
    output: Path,
    cols: int,
    rows: int,
    target_cell: tuple[int, int],
    target_head_x: int,
    target_foot_y: int,
    target_height: int | None,
    x_bounds: list[int] | None,
    largest_component: bool,
) -> None:
    sheet = Image.open(source).convert("RGBA")
    if x_bounds is None:
        x_bounds = [round(index * sheet.width / cols) for index in range(cols + 1)]
    if len(x_bounds) != cols + 1 or x_bounds[0] != 0 or x_bounds[-1] != sheet.width:
        raise ValueError("x-bounds must contain cols + 1 values spanning the sheet width")
    y_bounds = [round(index * sheet.height / rows) for index in range(rows + 1)]
    target = Image.new("RGBA", (target_cell[0] * cols, target_cell[1] * rows))

    for row in range(rows):
        for column in range(cols):
            frame = sheet.crop(
                (x_bounds[column], y_bounds[row], x_bounds[column + 1], y_bounds[row + 1])
            )
            if largest_component:
                frame = keep_largest_component(frame)
            bbox = alpha_bbox(frame)
            if target_height is not None:
                frame = frame.crop(bbox)
                scale = target_height / frame.height
                frame = frame.resize(
                    (round(frame.width * scale), target_height), Image.Resampling.LANCZOS
                )
                bbox = alpha_bbox(frame)
            head_x = head_center_x(frame, bbox)
            foot_y = bbox[3] - 1
            offset_x = target_head_x - head_x
            offset_y = target_foot_y - foot_y
            cell = Image.new("RGBA", target_cell)
            cell.alpha_composite(frame, (offset_x, offset_y))
            target.alpha_composite(cell, (column * target_cell[0], row * target_cell[1]))

    output.parent.mkdir(parents=True, exist_ok=True)
    target.save(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--cols", type=int, default=6)
    parser.add_argument("--rows", type=int, default=3)
    parser.add_argument("--cell-width", type=int, default=DEFAULT_TARGET_CELL[0])
    parser.add_argument("--cell-height", type=int, default=DEFAULT_TARGET_CELL[1])
    parser.add_argument("--head-x", type=int, default=DEFAULT_TARGET_HEAD_X)
    parser.add_argument("--foot-y", type=int, default=DEFAULT_TARGET_FOOT_Y)
    parser.add_argument("--target-height", type=int)
    parser.add_argument(
        "--x-bounds",
        help="Comma-separated source column boundaries for uneven generated strips",
    )
    parser.add_argument(
        "--largest-component",
        action="store_true",
        help="Discard disconnected spill from neighboring generated frames",
    )
    args = parser.parse_args()
    parsed_x_bounds = (
        [int(value) for value in args.x_bounds.split(",")] if args.x_bounds else None
    )
    normalize(
        args.source,
        args.output,
        args.cols,
        args.rows,
        (args.cell_width, args.cell_height),
        args.head_x,
        args.foot_y,
        args.target_height,
        parsed_x_bounds,
        args.largest_component,
    )


if __name__ == "__main__":
    main()
