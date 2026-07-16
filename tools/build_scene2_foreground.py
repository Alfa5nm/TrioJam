"""Build and validate semantic Scene 2 layers from one approved master plate."""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets" / "art" / "Scene 2"
MASTER = ART / "office-master-v2.png"
BACKGROUND = ART / "office-background-v2.png"
DESKS = ART / "office-desk-occluders-v2.png"
ARCHITECTURE = ART / "office-architecture-foreground-v2.png"
ID_MAP = ART / "office-layer-id-map-v2.png"
RECOMPOSED = ART / "office-recomposed-validation-v2.png"


def polygon_mask(size: tuple[int, int], polygons: list[tuple[tuple[int, int], ...]]) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    for polygon in polygons:
        draw.polygon(polygon, fill=255)
    return mask


def extracted(master: Image.Image, mask: Image.Image) -> Image.Image:
    layer = Image.new("RGBA", master.size)
    layer.paste(master, mask=mask)
    return layer


def main() -> None:
    master = Image.open(MASTER).convert("RGBA")
    if master.size != (1280, 720):
        raise ValueError(f"Scene 2 master must be 1280x720, got {master.size}")

    # Semantic desk masks: desktop lip plus the front faces that must hide legs.
    desk_polygons = [
        ((88, 437), (292, 437), (292, 515), (86, 515)),
        ((390, 438), (570, 438), (570, 515), (390, 515)),
    ]
    desk_mask = polygon_mask(master.size, desk_polygons)

    # Exact architectural occluders: window casing/mullions and thin open balcony rails.
    architecture_polygons = [
        ((35, 214), (854, 214), (854, 228), (35, 228)),
        ((35, 532), (854, 532), (854, 551), (35, 551)),
        ((34, 214), (54, 214), (54, 551), (34, 551)),
        ((341, 214), (362, 214), (362, 551), (341, 551)),
        ((624, 214), (644, 214), (644, 551), (624, 551)),
        ((834, 214), (854, 214), (854, 551), (834, 551)),
        # Balcony top and middle rails.
        ((872, 438), (1242, 438), (1242, 453), (872, 453)),
        ((872, 466), (1238, 466), (1238, 478), (872, 478)),
        ((872, 510), (1237, 510), (1237, 519), (872, 519)),
        # Sparse vertical posts preserve almost the entire target silhouette.
        ((872, 438), (886, 438), (886, 574), (872, 574)),
        ((1037, 438), (1051, 438), (1051, 574), (1037, 574)),
        ((1227, 438), (1242, 438), (1242, 574), (1227, 574)),
    ]
    architecture_mask = polygon_mask(master.size, architecture_polygons)

    union_mask = ImageChops.lighter(desk_mask, architecture_mask)
    background = master.copy()
    background.putalpha(ImageChops.invert(union_mask))
    desk_layer = extracted(master, desk_mask)
    architecture_layer = extracted(master, architecture_mask)

    # A color-coded artifact makes the authored depth ownership reviewable.
    id_map = Image.new("RGBA", master.size, (0, 0, 0, 0))
    id_map.paste((46, 168, 255, 220), mask=desk_mask)
    id_map.paste((255, 104, 72, 220), mask=architecture_mask)

    recomposed = Image.new("RGBA", master.size)
    recomposed.alpha_composite(background)
    recomposed.alpha_composite(desk_layer)
    recomposed.alpha_composite(architecture_layer)
    difference = ImageChops.difference(master, recomposed)
    if difference.getbbox() is not None:
        extrema = difference.getextrema()
        raise ValueError(f"Layer recomposition differs from master: {extrema}")

    for path, image in (
        (BACKGROUND, background),
        (DESKS, desk_layer),
        (ARCHITECTURE, architecture_layer),
        (ID_MAP, id_map),
        (RECOMPOSED, recomposed),
    ):
        image.save(path)
        print(f"Wrote {path.name}")
    print("Validated: recomposed layers are pixel-identical to the master")


if __name__ == "__main__":
    main()
