"""Create runtime-sized transparent pigeon takeoff frames from the AI source."""

from __future__ import annotations

from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
BIRD_DIR = PROJECT_ROOT / "assets/art/Day1 Scene 1/birds"
SOURCE = BIRD_DIR / "source/birds_animation_v2_rgba_full.png"
SHEET_OUTPUT = BIRD_DIR / "birds_animation_sheet_v2.png"
FRAME_SIZE = 256
GRID_SIZE = 3
FRAME_COUNT = 9


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    cell_width = source.width // GRID_SIZE
    cell_height = source.height // GRID_SIZE
    sheet = Image.new(
        "RGBA", (FRAME_SIZE * GRID_SIZE, FRAME_SIZE * GRID_SIZE), (0, 0, 0, 0)
    )

    for index in range(FRAME_COUNT):
        column = index % GRID_SIZE
        row = index // GRID_SIZE
        frame = source.crop(
            (
                column * cell_width,
                row * cell_height,
                (column + 1) * cell_width,
                (row + 1) * cell_height,
            )
        )
        frame = frame.resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.LANCZOS)
        frame_path = BIRD_DIR / f"birds_animation_v2_frame_{index + 1:02d}.png"
        frame.save(frame_path, optimize=True)
        sheet.paste(frame, (column * FRAME_SIZE, row * FRAME_SIZE), frame)

    sheet.save(SHEET_OUTPUT, optimize=True)
    alpha = sheet.getchannel("A")
    print(
        f"Wrote {SHEET_OUTPUT.name}: {sheet.width}x{sheet.height}, "
        f"{FRAME_COUNT} frames at {FRAME_SIZE}x{FRAME_SIZE}, alpha={alpha.getextrema()}"
    )


if __name__ == "__main__":
    main()
