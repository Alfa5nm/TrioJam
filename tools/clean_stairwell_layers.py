"""Bake the stairwell railing checkerboard cleanup into real alpha PNGs."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets" / "art" / "Scene 0" / "stairwell_layers_true_transparency"
LAYERS = {
    "layer_03_midground_railings.png": "layer_03_midground_railings_alpha.png",
    "layer_04_foreground.png": "layer_04_foreground_alpha.png",
}
UPPER_LANDING_RAIL = "upper_landing_front_rail_alpha.png"


def remove_checker(source: Path, output: Path) -> None:
    image = Image.open(source).convert("RGBA")
    pixels = image.load()
    removed = 0
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            brightest = max(red, green, blue) / 255.0
            darkest = min(red, green, blue) / 255.0
            if darkest > 0.70 and brightest - darkest < 0.09:
                pixels[x, y] = (red, green, blue, 0)
                removed += 1
            elif alpha:
                # Preserve the authored edge alpha and reject invisible RGB noise.
                pixels[x, y] = (red, green, blue, alpha)
    image.save(output)
    print(f"Wrote {output.name}: removed {removed} checker pixels")


def main() -> None:
    for source_name, output_name in LAYERS.items():
        remove_checker(SOURCE_DIR / source_name, SOURCE_DIR / output_name)
    midground = Image.open(SOURCE_DIR / LAYERS["layer_03_midground_railings.png"]).convert("RGBA")
    landing_rail = Image.new("RGBA", midground.size)
    # The camera-facing rail beside the top-left door is the only portion of
    # the midground sheet that must return in front of the player.
    landing_rail.alpha_composite(midground.crop((0, 96, 448, 292)), (0, 96))
    landing_rail.save(SOURCE_DIR / UPPER_LANDING_RAIL)
    print(f"Wrote {UPPER_LANDING_RAIL}")


if __name__ == "__main__":
    main()
