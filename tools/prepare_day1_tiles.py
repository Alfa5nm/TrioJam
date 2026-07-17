"""Prepare the Day 1 environment atlas for Godot.

The source is an RGB sheet with a near-white connected background.  This script
removes only that connected background, preserves the original pixels, and
exports tightly cropped RGBA props for use as TileSet atlas sources.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT_ROOT / "assets/art/Day1 Scene 1/ChatGPT Image Jul 17, 2026, 04_11_10 PM (2).png"
BACKUP = SOURCE.with_name(f"{SOURCE.stem}.original-rgb.png")
OUTPUT_DIR = SOURCE.parent / "tiles"

# Rectangles are deliberately separated along the generous gutters in the
# source sheet.  Each crop is trimmed again after alpha extraction.
REGIONS: dict[str, tuple[int, int, int, int]] = {
    "notice_board": (8, 42, 338, 376),
    "authority_entrance": (390, 42, 392, 376),
    "authority_sign": (826, 44, 338, 98),
    "iron_gate": (814, 158, 378, 280),
    "one_voice_poster": (1238, 66, 168, 236),
    "frequency_poster": (1210, 305, 210, 151),
    "broadcast_signpost": (1448, 48, 216, 804),
    "walled_fence": (18, 436, 362, 224),
    "tree": (405, 419, 278, 274),
    "broadcast_antenna": (674, 440, 282, 252),
    "authority_building": (984, 480, 468, 246),
    "security_door": (40, 668, 112, 226),
    "barred_window": (170, 692, 154, 168),
    "wall_lamp": (348, 678, 66, 150),
    "hanging_vines": (430, 690, 210, 220),
    "sidewalk_light": (650, 720, 580, 93),
    "sidewalk_road": (650, 813, 590, 102),
    "authority_emblem": (1268, 744, 158, 158),
}


def background_matte(rgb: np.ndarray) -> np.ndarray:
    """Return pixels belonging to the source sheet's off-white matte.

    The strict color and brightness limits preserve aged pale details while
    also clearing matte pockets enclosed by fence bars and prop silhouettes.
    """

    edge = np.concatenate((rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]), axis=0)
    key = np.median(edge, axis=0)
    delta = rgb.astype(np.int32) - key.astype(np.int32)
    distance = np.sqrt(np.sum(delta * delta, axis=2))
    channel_spread = rgb.max(axis=2).astype(np.int16) - rgb.min(axis=2).astype(np.int16)
    candidate = (distance <= 18.0) & (channel_spread <= 18) & (rgb.min(axis=2) >= 215)

    return candidate


def make_rgba(source: Image.Image) -> Image.Image:
    rgb = np.asarray(source.convert("RGB"))
    background = background_matte(rgb)
    alpha = Image.fromarray((~background * 255).astype(np.uint8), mode="L")
    # Contract by one pixel before feathering so the original off-white matte
    # cannot produce a bright fringe around filtered tile edges.
    alpha = alpha.filter(ImageFilter.MinFilter(3))
    alpha = alpha.filter(ImageFilter.GaussianBlur(radius=0.45))
    rgba = source.convert("RGBA")
    rgba.putalpha(alpha)
    return rgba


def export_tiles(rgba: Image.Image) -> dict[str, dict[str, object]]:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, dict[str, object]] = {}

    for name, rect in REGIONS.items():
        x, y, width, height = rect
        crop = rgba.crop((x, y, x + width, y + height))
        alpha_bbox = crop.getchannel("A").point(lambda value: 255 if value >= 20 else 0).getbbox()
        if alpha_bbox is None:
            raise RuntimeError(f"Region {name!r} contains no visible pixels")

        # Keep two transparent pixels around each prop to protect filtered edges.
        left = max(0, alpha_bbox[0] - 2)
        top = max(0, alpha_bbox[1] - 2)
        right = min(width, alpha_bbox[2] + 2)
        bottom = min(height, alpha_bbox[3] + 2)
        crop = crop.crop((left, top, right, bottom))

        output = OUTPUT_DIR / f"{name}.png"
        crop.save(output, optimize=True)
        manifest[name] = {
            "file": output.relative_to(PROJECT_ROOT).as_posix(),
            "source_rect": [x + left, y + top, right - left, bottom - top],
            "size": list(crop.size),
        }

    return manifest


def main() -> None:
    source_path = BACKUP if BACKUP.exists() else SOURCE
    source = Image.open(source_path).convert("RGB")
    if not BACKUP.exists():
        source.save(BACKUP, optimize=True)

    rgba = make_rgba(source)
    rgba.save(SOURCE, optimize=True)
    manifest = export_tiles(rgba)
    (OUTPUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )

    alpha = np.asarray(rgba.getchannel("A"))
    print(f"Prepared {SOURCE.name}: {rgba.size[0]}x{rgba.size[1]} RGBA")
    print(f"Transparent pixels: {(alpha == 0).sum():,}; visible pixels: {(alpha > 0).sum():,}")
    print(f"Exported {len(manifest)} tiles to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
