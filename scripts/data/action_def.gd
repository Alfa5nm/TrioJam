class_name ActionDef
extends Resource

@export var id: StringName = &""
@export var display_name := ""
## Shown in a frame slot in place of the text label once that slot's scene+character
## combination matches a known-correct sequence (truthful or propaganda) for that position.
@export var scene_image: Texture2D = null
## How many characters this specific scene accepts (e.g. a single-person scene
## like "Protest" caps at 1, while "Licensing Seeds" needs 2). Overrides the
## report's own max_characters_per_frame once this scene is placed in a frame.
@export var max_characters := 2
