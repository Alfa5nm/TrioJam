"""Normalize the generated Day 3 pistol poses into the player's 8x512 atlas."""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/art/Day3/mc-pistol-animation-alpha.png"
OUTPUT = ROOT / "assets/art/characters/office-worker-pistol-sheet.png"
FRAME_COUNT = 8
FRAME_SIZE = 512
TARGET_BODY_HEIGHT = 310
FOOT_BASELINE = 472


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    atlas = Image.new("RGBA", (FRAME_SIZE * FRAME_COUNT, FRAME_SIZE), (0, 0, 0, 0))
    for index in range(FRAME_COUNT):
        # Image generation can return a width that is not an exact multiple of
        # eight; rounded proportional boundaries preserve the authored row.
        left = round(index * source.width / FRAME_COUNT)
        right = round((index + 1) * source.width / FRAME_COUNT)
        cell = source.crop((left, 0, right, source.height))
        alpha = cell.getchannel("A")
        bounds = alpha.getbbox()
        if bounds is None:
            raise ValueError(f"Frame {index + 1} is empty")
        pose = cell.crop(bounds)
        scale = TARGET_BODY_HEIGHT / pose.height
        resized = pose.resize((round(pose.width * scale), TARGET_BODY_HEIGHT), Image.Resampling.LANCZOS)
        x = index * FRAME_SIZE + (FRAME_SIZE - resized.width) // 2
        y = FOOT_BASELINE - resized.height
        atlas.alpha_composite(resized, (x, y))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUTPUT)
    print(f"Wrote {OUTPUT} ({atlas.width}x{atlas.height})")


if __name__ == "__main__":
    main()
