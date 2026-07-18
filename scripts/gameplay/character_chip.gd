class_name CharacterChip
extends VBoxContainer

var character: CharacterDef

@onready var portrait_rect: TextureRect = $Portrait
@onready var name_label: Label = $NameLabel


func _ready() -> void:
	_refresh_visual()
	mouse_entered.connect(_animate_hover.bind(true))
	mouse_exited.connect(_animate_hover.bind(false))


func setup(p_character: CharacterDef) -> void:
	character = p_character
	if is_node_ready():
		_refresh_visual()


func _refresh_visual() -> void:
	if character == null:
		return
	portrait_rect.texture = character.get_display_texture()
	name_label.text = character.display_name


func _get_drag_data(_at_position: Vector2) -> Variant:
	var payload: Variant = drag_payload()
	if payload == null:
		return null
	set_drag_preview(_build_preview())
	return payload


func drag_payload() -> Variant:
	if character == null:
		return null
	return {"type": "broadcast_character", "character": character}


func _build_preview() -> Control:
	var preview := TextureRect.new()
	preview.texture = character.get_display_texture()
	preview.custom_minimum_size = Vector2(72, 72)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate.a = 0.85
	return preview


func _animate_hover(active: bool) -> void:
	pivot_offset = size * 0.5
	var target_scale := Vector2(1.08, 1.08) if active else Vector2.ONE
	var target_rotation := deg_to_rad(-2.0) if active else 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", target_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", target_rotation, 0.12)
