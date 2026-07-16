class_name ActionDef
extends Resource

@export var id: StringName = &""
@export var display_name := ""
## Shown in a frame slot in place of the text label once that slot's scene+character
## combination matches a known-correct sequence (truthful or propaganda) for that position.
@export var scene_image: Texture2D = null
