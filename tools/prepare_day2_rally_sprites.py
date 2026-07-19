"""Prepare generated Day 2 rally sprites for Godot.

The image generator produces chroma-keyed source art.  This script removes the
green background, normalizes every pose to a 384x384 cell with a shared foot
baseline, and exports both individual frames and runtime strips.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from math import sqrt

from PIL import Image


CELL_SIZE = 384
BASELINE_Y = 374
TARGET_HEIGHT = 326


def remove_green(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, _ = pixels[x, y]
            # Generated backgrounds are strongly green.  Keep blue clothing and
            # antialiased dark outlines intact while softly removing green spill.
            key_distance = sqrt(red * red + (255 - green) * (255 - green) + blue * blue)
            if green > max(red, blue) + 8:
                alpha = max(0, min(255, int((key_distance - 18.0) / 112.0 * 255.0)))
                green = min(green, max(red, blue))
                pixels[x, y] = (red, green, blue, alpha)
    return rgba


def normalize_pose(pose: Image.Image, target_height: int = TARGET_HEIGHT) -> Image.Image:
    alpha = pose.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("No opaque subject found in generated pose")
    subject = pose.crop(bounds)
    scale = min((CELL_SIZE - 18) / subject.width, target_height / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.LANCZOS)
    cell = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    x = (CELL_SIZE - subject.width) // 2
    y = BASELINE_Y - subject.height
    cell.alpha_composite(subject, (x, y))
    return cell


def prepare_leader(source: Path, output: Path) -> None:
    result = normalize_pose(remove_green(Image.open(source)), target_height=342)
    output.parent.mkdir(parents=True, exist_ok=True)
    result.save(output)


def prepare_strip(source: Path, output_dir: Path, strip_output: Path) -> None:
    chroma = remove_green(Image.open(source))
    cell_width = chroma.width / 3.0
    frames: list[Image.Image] = []
    output_dir.mkdir(parents=True, exist_ok=True)
    for index in range(3):
        left = round(index * cell_width)
        right = round((index + 1) * cell_width)
        frame = normalize_pose(chroma.crop((left, 0, right, chroma.height)))
        frame.save(output_dir / f"frame-{index + 1}.png")
        frames.append(frame)
    strip = Image.new("RGBA", (CELL_SIZE * 3, CELL_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * CELL_SIZE, 0))
    strip_output.parent.mkdir(parents=True, exist_ok=True)
    strip.save(strip_output)


def validate(root: Path) -> None:
    pngs = sorted(path for path in root.rglob("*.png") if "source" not in path.parts)
    if not pngs:
        raise ValueError("No prepared PNG files found")
    for path in pngs:
        image = Image.open(path).convert("RGBA")
        expected = (1152, 384) if path.name == "strip.png" else (384, 384)
        if image.size != expected:
            raise ValueError(f"{path}: expected {expected}, got {image.size}")
        corners = [(0, 0), (image.width - 1, 0), (0, image.height - 1), (image.width - 1, image.height - 1)]
        if any(image.getpixel(point)[3] != 0 for point in corners):
            raise ValueError(f"{path}: a corner is not transparent")
        if image.getchannel("A").getbbox() is None:
            raise ValueError(f"{path}: image has no visible subject")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    prepare_leader(args.source_dir / "peace-leader-chroma.png", args.output_dir / "peace-leader.png")
    identities = [
        "r1c3-occupation-protester-b",
        "r2c3-gossiping-gal-a",
        "r2c4-gossiping-gal-b",
        "r4c1-anti-seedless-protester-a",
        "r4c4-anti-seedless-protester-d",
    ]
    for identity in identities:
        prepare_strip(
            args.source_dir / f"{identity}-chroma.png",
            args.output_dir / "dispersal" / identity,
            args.output_dir / "dispersal" / identity / "strip.png",
        )
    validate(args.output_dir)


if __name__ == "__main__":
    main()
