class_name CharacterChip
extends VBoxContainer

var character: CharacterDef

@onready var portrait_rect: TextureRect = $Portrait
@onready var name_label: Label = $NameLabel


func _ready() -> void:
	_refresh_visual()


func setup(p_character: CharacterDef) -> void:
	character = p_character
	if is_node_ready():
		_refresh_visual()


func _refresh_visual() -> void:
	if character == null:
		return
	portrait_rect.texture = character.portrait_texture
	name_label.text = character.display_name


func _get_drag_data(_at_position: Vector2) -> Variant:
	if character == null or character.portrait_texture == null:
		return null
	set_drag_preview(_build_preview())
	return {"type": "broadcast_character", "character": character}


func _build_preview() -> Control:
	var preview := TextureRect.new()
	preview.texture = character.portrait_texture
	preview.custom_minimum_size = Vector2(72, 72)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate.a = 0.85
	return preview
