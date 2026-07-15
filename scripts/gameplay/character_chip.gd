class_name CharacterChip
extends VBoxContainer

var character: CharacterDef

@onready var circle: PanelContainer = $Circle
@onready var initial_label: Label = $Circle/InitialLabel
@onready var name_label: Label = $NameLabel

var _style: StyleBoxFlat


func _ready() -> void:
	_style = (circle.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	circle.add_theme_stylebox_override("panel", _style)
	_refresh_visual()


func setup(p_character: CharacterDef) -> void:
	character = p_character
	if is_node_ready():
		_refresh_visual()


func _refresh_visual() -> void:
	if character == null:
		return
	_style.bg_color = character.portrait_color
	initial_label.text = character.display_name.substr(0, 1)
	name_label.text = character.display_name


func _get_drag_data(_at_position: Vector2) -> Variant:
	if character == null:
		return null
	set_drag_preview(_build_preview())
	return {"type": "broadcast_character", "character": character}


func _build_preview() -> Control:
	var preview := Label.new()
	preview.text = character.display_name
	preview.add_theme_color_override("font_color", Color(0.878, 0.902, 0.949, 1))
	preview.modulate.a = 0.85
	return preview
