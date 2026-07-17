"""Split the stairwell railing plates into non-overlapping semantic layers."""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
LAYER_DIR = ROOT / "assets" / "art" / "Scene 0" / "stairwell_layers_true_transparency"
MIDGROUND_SOURCE = LAYER_DIR / "layer_03_midground_railings_alpha.png"
FOREGROUND_SOURCE = LAYER_DIR / "layer_04_foreground_alpha.png"

# Covers the complete upper flight while cutting between authored railing joints.
UPPER_FLIGHT_POLYGON = [
    (620, 585),
    (1145, 270),
    (1215, 270),
    (1220, 312),
    (1282, 312),
    (1300, 505),
    (1160, 505),
    (690, 800),
    (620, 800),
]


def masked_layer(source: Image.Image, mask: Image.Image) -> Image.Image:
    result = source.copy()
    result.putalpha(ImageChops.multiply(source.getchannel("A"), mask))
    return result


def main() -> None:
    midground = Image.open(MIDGROUND_SOURCE).convert("RGBA")
    foreground = Image.open(FOREGROUND_SOURCE).convert("RGBA")
    if midground.size != foreground.size:
        raise ValueError("Stairwell railing sources must share one canvas size")

    upper_mask = Image.new("L", midground.size, 0)
    ImageDraw.Draw(upper_mask).polygon(UPPER_FLIGHT_POLYGON, fill=255)
    rear_mask = ImageChops.invert(upper_mask)

    masked_layer(midground, rear_mask).save(LAYER_DIR / "layer_03_rear_railings_alpha.png")
    masked_layer(foreground, rear_mask).save(LAYER_DIR / "layer_04_lower_foreground_alpha.png")
    masked_layer(midground, upper_mask).save(LAYER_DIR / "upper_flight_foreground_alpha.png")


if __name__ == "__main__":
    main()
