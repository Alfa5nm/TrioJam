"""Prepare supplied Day 1 encounter characters as runtime sprites.

This keeps reproducible source copies, cleans the older flattened smoking-NPC
source, and bottom-aligns every actor on a transparent 256x256 canvas. New RGBA
checkpoint sprites retain their authored edges unchanged.
"""

from __future__ import annotations

from pathlib import Path
import shutil

import cv2
import numpy as np
from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_ROOT / "assets/art/Day1 Scene 1/encounters"
SOURCE_DIR = OUTPUT_DIR / "source"
SUPPLIED_SMOKER = Path(
    r"C:\Users\alfar\AppData\Local\Temp\codex-clipboard-24f48903-2d45-4c68-8e77-1dab2ae32866.png"
)
SUPPLIED_SOLDIER = Path(r"C:\Users\alfar\Pictures\Scene01\broadcast v2\3.png")
SUPPLIED_BOY = Path(r"C:\Users\alfar\Pictures\Scene01\broadcast v2\4.png")
SMOKER_SOURCE = SOURCE_DIR / "smoking-civilian-supplied.png"
SOLDIER_SOURCE = SOURCE_DIR / "checkpoint-soldier-supplied.png"
BOY_SOURCE = SOURCE_DIR / "checkpoint-boy-supplied.png"
CANVAS_SIZE = 256
FOOTLINE = 246


def ensure_source_copy(supplied: Path, project_copy: Path) -> Path:
    project_copy.parent.mkdir(parents=True, exist_ok=True)
    if supplied.exists():
        shutil.copy2(supplied, project_copy)
    if not project_copy.exists():
        raise FileNotFoundError(f"Missing supplied source and project copy: {project_copy}")
    return project_copy


def extract_actor(
    source: Image.Image,
    crop_box: tuple[int, int, int, int],
    target_height: int,
) -> Image.Image:
    crop = source.crop(crop_box).convert("RGB")
    rgb = np.asarray(crop, dtype=np.uint8)
    brightness = rgb.max(axis=2)

    # Keep only the largest connected bright silhouette. Filling its interior
    # preserves dark navy details, while the outer edge starts at authored color
    # rather than expanding into the source image's black background.
    seed = np.where(brightness >= 22, 1, 0).astype(np.uint8)
    component_count, labels, stats, _centroids = cv2.connectedComponentsWithStats(seed, 8)
    if component_count <= 1:
        raise RuntimeError(f"No foreground found in crop {crop_box}")
    largest_component = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    silhouette = np.where(labels == largest_component, 255, 0).astype(np.uint8)
    flood = silhouette.copy()
    flood_mask = np.zeros((flood.shape[0] + 2, flood.shape[1] + 2), dtype=np.uint8)
    cv2.floodFill(flood, flood_mask, (0, 0), 255)
    silhouette = cv2.bitwise_or(silhouette, cv2.bitwise_not(flood))
    alpha = Image.fromarray(silhouette, "L")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError(f"No foreground found in crop {crop_box}")

    rgba = crop.convert("RGBA")
    rgba.putalpha(alpha)
    rgba = rgba.crop(bbox)
    scale = target_height / rgba.height
    target_width = max(1, round(rgba.width * scale))
    # Resize in premultiplied-alpha space. This prevents the flattened source
    # background from bleeding into transparent pixels without eroding or
    # recoloring any of the smoking civilian's authored dark linework.
    rgba = rgba.convert("RGBa").resize(
        (target_width, target_height), Image.Resampling.LANCZOS
    ).convert("RGBA")

    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    x = (CANVAS_SIZE - rgba.width) // 2
    y = FOOTLINE - rgba.height
    canvas.alpha_composite(rgba, (x, y))
    return canvas


def save_actor(name: str, image: Image.Image) -> None:
    path = OUTPUT_DIR / name
    image.save(path, optimize=True)
    alpha = image.getchannel("A")
    print(f"Wrote {path.name}: {image.size}, alpha={alpha.getextrema()}, bbox={alpha.getbbox()}")


def normalize_transparent_actor(source: Image.Image, target_height: int) -> Image.Image:
    rgba = source.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Transparent actor source contains no visible pixels")
    rgba = rgba.crop(bbox)
    scale = target_height / rgba.height
    target_width = max(1, round(rgba.width * scale))
    rgba = rgba.resize((target_width, target_height), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    x = (CANVAS_SIZE - rgba.width) // 2
    y = FOOTLINE - rgba.height
    canvas.alpha_composite(rgba, (x, y))
    return canvas


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    smoker_path = ensure_source_copy(SUPPLIED_SMOKER, SMOKER_SOURCE)
    soldier_path = ensure_source_copy(SUPPLIED_SOLDIER, SOLDIER_SOURCE)
    boy_path = ensure_source_copy(SUPPLIED_BOY, BOY_SOURCE)
    smoker = Image.open(smoker_path).convert("RGB")
    soldier = Image.open(soldier_path).convert("RGBA")
    boy = Image.open(boy_path).convert("RGBA")

    save_actor("checkpoint-soldier.png", normalize_transparent_actor(soldier, 192))
    save_actor("checkpoint-boy.png", normalize_transparent_actor(boy, 180))
    save_actor("smoking-civilian.png", extract_actor(smoker, (4, 14, 106, 216), 194))


if __name__ == "__main__":
    main()
