"""Split the generated Day 3 placeholder grid into 16:9 runtime CGs."""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/art/Day3/placeholder-cg-grid.png"
OUTPUTS = (
    "assassination-aftermath-placeholder.png",
    "opposition-arrests-placeholder.png",
    "helicopter-escape-placeholder.png",
    "false-passports-placeholder.png",
)
TARGET = (1280, 720)


def cover_resize(image: Image.Image, target: tuple[int, int]) -> Image.Image:
    target_ratio = target[0] / target[1]
    ratio = image.width / image.height
    if ratio > target_ratio:
        width = round(image.height * target_ratio)
        left = (image.width - width) // 2
        image = image.crop((left, 0, left + width, image.height))
    else:
        height = round(image.width / target_ratio)
        top = (image.height - height) // 2
        image = image.crop((0, top, image.width, top + height))
    return image.resize(target, Image.Resampling.LANCZOS)


def main() -> None:
    sheet = Image.open(SOURCE).convert("RGB")
    gutter = max(10, round(min(sheet.size) * 0.012))
    center_x, center_y = sheet.width // 2, sheet.height // 2
    boxes = (
        (gutter, gutter, center_x - gutter // 2, center_y - gutter // 2),
        (center_x + gutter // 2, gutter, sheet.width - gutter, center_y - gutter // 2),
        (gutter, center_y + gutter // 2, center_x - gutter // 2, sheet.height - gutter),
        (center_x + gutter // 2, center_y + gutter // 2, sheet.width - gutter, sheet.height - gutter),
    )
    for filename, box in zip(OUTPUTS, boxes):
        output = ROOT / "assets/art/Day3" / filename
        cover_resize(sheet.crop(box), TARGET).save(output)
        print(f"Wrote {output}")


if __name__ == "__main__":
    main()
