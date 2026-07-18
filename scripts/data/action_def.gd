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
## Optional per-character artwork (keyed by CharacterDef.id) drawn full-frame on
## top of scene_image once that character is placed in this scene's frame —
## e.g. the same rooftop photo shows either the MC or the Opposition Person
## physically standing in it, depending on which character chip is dropped.
## Each value is either a single Texture2D (shown regardless of placement order)
## or an Array[Texture2D] indexed by that character's position within the frame's
## current_characters — used by order_sensitive scenes where the same character
## needs a different pose depending on whether they're first (e.g. the attacker)
## or second (e.g. the target). Empty for scenes with no such art; those just
## keep showing scene_image alone.
@export var character_overlays: Dictionary = {}
