class_name CharacterDef
extends Resource

const PLACEHOLDER_SIZE := 96

@export var id: StringName = &""
@export var display_name := ""
@export var portrait_color := Color(0.243, 0.761, 0.91, 1)
@export var portrait_texture: Texture2D = null

var _placeholder_texture: ImageTexture


## Returns portrait_texture when set, otherwise a lazily-built solid-color
## circle tinted to portrait_color — a stand-in for characters without art yet.
func get_display_texture() -> Texture2D:
	if portrait_texture != null:
		return portrait_texture
	if _placeholder_texture == null:
		_placeholder_texture = ImageTexture.create_from_image(_build_placeholder_image())
	return _placeholder_texture


func _build_placeholder_image() -> Image:
	var image := Image.create(PLACEHOLDER_SIZE, PLACEHOLDER_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(PLACEHOLDER_SIZE, PLACEHOLDER_SIZE) * 0.5
	var radius := PLACEHOLDER_SIZE * 0.5 - 2.0
	for y in PLACEHOLDER_SIZE:
		for x in PLACEHOLDER_SIZE:
			if Vector2(x, y).distance_to(center) <= radius:
				image.set_pixel(x, y, portrait_color)
	return image
