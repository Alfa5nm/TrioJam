# Art asset notes

The current stairwell and office-worker assets are original AI-assisted game-jam assets generated for this project. The supplied layout sketch was used as the architectural authority; external screenshots were used only as references for cinematic pixel-art density, restrained color, lighting, and depth.

## Runtime files

- `environment/stairwell-base.png`: 16:9 stairwell environment plate.
- `environment/stairwell-normal.png`: luminance-derived tangent-space normal map.
- `characters/office-worker-sheet.png`: transparent 4-by-2 character atlas.
- `characters/office-worker-sheet-normal.png`: matching character normal atlas.

The character sheet uses four equal columns and two equal rows. The top row contains idle and interaction poses. The bottom row contains four walk-cycle poses. Keep the 4-by-2 registration if the art is replaced without updating `scenes/player/player.tscn`.
