"""Convert generated chroma-key Day 2 aftermath sheets into Godot sprites."""

from __future__ import annotations

import argparse
from pathlib import Path
from PIL import Image


CELL = 384
BASELINE = 374


def remove_green(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    px = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, _ = px[x, y]
            if r > 242 and g > 242 and b > 242:
                px[x, y] = (255, 255, 255, 0)
                continue
            dominance = g - max(r, b)
            if dominance > 8:
                alpha = max(0, min(255, int((dominance - 8) * -3.0 + 255.0)))
                if dominance > 70:
                    alpha = 0
                px[x, y] = (r, min(g, max(r, b)), b, alpha)
    return rgba


def normalize(source: Image.Image, target_height: int, baseline: int = BASELINE) -> Image.Image:
    bounds = source.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("generated cell has no opaque subject")
    subject = source.crop(bounds)
    scale = min((CELL - 18) / subject.width, target_height / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (CELL, CELL))
    out.alpha_composite(subject, ((CELL - subject.width) // 2, baseline - subject.height))
    return out


def split_horizontal(source: Path, out_dir: Path, stem: str, target_height: int) -> None:
    sheet = remove_green(Image.open(source))
    out_dir.mkdir(parents=True, exist_ok=True)
    frames = []
    for index in range(2):
        left = round(index * sheet.width / 2)
        right = round((index + 1) * sheet.width / 2)
        frame = normalize(sheet.crop((left, 0, right, sheet.height)), target_height)
        frame.save(out_dir / f"{stem}-{index + 1}.png")
        frames.append(frame)
    strip = Image.new("RGBA", (CELL * 2, CELL))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * CELL, 0))
    strip.save(out_dir / f"{stem}-strip.png")


def split_casualties(source: Path, out_dir: Path) -> None:
    sheet = Image.open(source).convert("RGB")
    # The generator leaves narrow white gutters; crop inside each quadrant.
    names = ["deceased-a", "deceased-b", "injured-a", "injured-b"]
    out_dir.mkdir(parents=True, exist_ok=True)
    for row in range(2):
        for col in range(2):
            left = round(col * sheet.width / 2) + 22
            right = round((col + 1) * sheet.width / 2) - 22
            top = round(row * sheet.height / 2) + 22
            bottom = round((row + 1) * sheet.height / 2) - 22
            keyed = remove_green(sheet.crop((left, top, right, bottom)))
            frame = normalize(keyed, 210 if row == 0 else 260)
            frame.save(out_dir / f"{names[row * 2 + col]}.png")


def split_injured_animations(source: Path, out_dir: Path) -> None:
    sheet = Image.open(source).convert("RGB")
    out_dir.mkdir(parents=True, exist_ok=True)
    for row, stem in enumerate(("injured-a", "injured-b")):
        frames = []
        for col in range(2):
            left = round(col * sheet.width / 2) + 18
            right = round((col + 1) * sheet.width / 2) - 18
            top = round(row * sheet.height / 2) + 18
            bottom = round((row + 1) * sheet.height / 2) - 18
            keyed = remove_green(sheet.crop((left, top, right, bottom)))
            frame = normalize(keyed, 245 if row == 0 else 265)
            frame.save(out_dir / f"{stem}-{col + 1}.png")
            frames.append(frame)
        strip = Image.new("RGBA", (CELL * 2, CELL))
        for index, frame in enumerate(frames):
            strip.alpha_composite(frame, (index * CELL, 0))
        strip.save(out_dir / f"{stem}-strip.png")


def validate(out_dir: Path) -> None:
    for path in out_dir.rglob("*.png"):
        if "source" in path.parts:
            continue
        image = Image.open(path).convert("RGBA")
        expected = (768, 384) if path.name.endswith("-strip.png") else (384, 384)
        if image.size != expected:
            raise ValueError(f"{path}: {image.size} != {expected}")
        if image.getpixel((0, 0))[3] or image.getpixel((image.width - 1, image.height - 1))[3]:
            raise ValueError(f"{path}: non-transparent corner")
        if image.getchannel("A").getbbox() is None:
            raise ValueError(f"{path}: empty")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    split_horizontal(args.source_dir / "injured-leader-chroma.png", args.out_dir / "leader", "injured-leader", 330)
    split_horizontal(args.source_dir / "bomb-soldier-chroma.png", args.out_dir / "bomb-soldier", "bomb-soldier", 300)
    split_casualties(args.source_dir / "casualties-chroma.png", args.out_dir / "casualties")
    split_injured_animations(args.source_dir / "injured-civilians-chroma.png", args.out_dir / "casualties")
    validate(args.out_dir)


if __name__ == "__main__":
    main()
