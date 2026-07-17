"""Generate tangent-space normal maps for the current 2D environment plates."""

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
STAIR = ROOT / "assets" / "art" / "Scene 0" / "stairwell_layers_true_transparency"
JOBS = {
    STAIR / "layer_01_background_shell.png": (STAIR / "layer_01_background_shell-normal.png", 2.1),
    STAIR / "1234.png": (STAIR / "1234-normal.png", 2.0),
    STAIR / "layer_02_props_and_lighting.png": (STAIR / "layer_02_props_and_lighting-normal.png", 2.8),
    STAIR / "layer_03_rear_railings_alpha.png": (STAIR / "layer_03_rear_railings-normal.png", 4.0),
    STAIR / "layer_04_lower_foreground_alpha.png": (STAIR / "layer_04_lower_foreground-normal.png", 4.0),
    STAIR / "upper_flight_foreground_alpha.png": (STAIR / "upper_flight_foreground-normal.png", 4.2),
    STAIR / "upper_landing_front_rail_alpha.png": (STAIR / "upper_landing_front_rail-normal.png", 4.2),
    STAIR / "top stair.png": (STAIR / "top-stair-normal.png", 2.7),
    STAIR / "layer_06_debris.png": (STAIR / "layer_06_debris-normal.png", 3.2),
    ROOT / "assets" / "art" / "Scene 1" / "Rooftop Scene.png": (
        ROOT / "assets" / "art" / "Scene 1" / "Rooftop Scene-normal.png",
        2.35,
    ),
}


def generate(source_path: Path, output_path: Path, strength: float) -> None:
    source = Image.open(source_path).convert("RGBA")
    rgba = np.asarray(source, dtype=np.float32) / 255.0
    luminance = rgba[..., 0] * 0.299 + rgba[..., 1] * 0.587 + rgba[..., 2] * 0.114
    height = Image.fromarray(np.uint8(np.clip(luminance * rgba[..., 3], 0.0, 1.0) * 255))
    height = np.asarray(height.filter(ImageFilter.GaussianBlur(1.15)), dtype=np.float32) / 255.0

    gradient_y, gradient_x = np.gradient(height)
    normal_x = -gradient_x * strength
    normal_y = -gradient_y * strength
    normal_z = np.ones_like(normal_x)
    length = np.sqrt(normal_x * normal_x + normal_y * normal_y + normal_z * normal_z)
    normals = np.stack((normal_x / length, normal_y / length, normal_z / length), axis=-1)
    encoded = np.uint8(np.clip(normals * 0.5 + 0.5, 0.0, 1.0) * 255)
    alpha = np.uint8(rgba[..., 3] * 255)[..., None]
    Image.fromarray(np.concatenate((encoded, alpha), axis=-1), "RGBA").save(output_path)
    print(f"Wrote {output_path.relative_to(ROOT)}")


def main() -> None:
    for source, (output, strength) in JOBS.items():
        generate(source, output, strength)


if __name__ == "__main__":
    main()
