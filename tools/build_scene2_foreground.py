"""Extract the office architecture that must render in front of Scene 2 actors."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "art" / "Scene 2" / "office-target-building.png"
OUTPUT = ROOT / "assets" / "art" / "Scene 2" / "office-foreground-overlay.png"


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    mask = Image.new("L", source.size, 0)
    draw = ImageDraw.Draw(mask)

    # Window casing and mullions keep every worker visibly behind the glazing.
    draw.rectangle((27, 187, 838, 216), fill=255)
    draw.rectangle((27, 485, 838, 516), fill=255)
    for left, right in ((27, 53), (334, 359), (625, 651), (812, 839)):
        draw.rectangle((left, 187, right, 516), fill=255)

    # Front faces of the two occupied desks. Hands remain visible above y=402.
    draw.polygon(((105, 402), (321, 402), (321, 490), (105, 490)), fill=255)
    draw.polygon(((446, 404), (596, 404), (596, 490), (446, 490)), fill=255)

    # Balcony cap, parapet and railing hide the target's lower body correctly.
    draw.polygon(((966, 404), (1181, 420), (1181, 545), (966, 536)), fill=255)
    draw.rectangle((965, 398, 1183, 433), fill=255)

    overlay = Image.new("RGBA", source.size)
    overlay.paste(source, mask=mask)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    overlay.save(OUTPUT)
    print(f"Wrote {OUTPUT}")


if __name__ == "__main__":
    main()
