class_name FrameSlot
extends PanelContainer

signal composition_changed(slot: FrameSlot)

@export var slot_label := "CAUSE"

const MAX_CHARACTERS := 2

const COLOR_EMPTY_BORDER := Color(0.71, 0.745, 0.81, 0.35)
const COLOR_FILLED_BORDER := Color(0.243, 0.761, 0.91, 0.9)
const COLOR_SUCCESS_BORDER := Color(0.294, 0.812, 0.49, 1)
const COLOR_FAIL_BORDER := Color(0.714, 0.275, 0.310, 1)
const COLOR_HIGHLIGHT_BORDER := Color(0.976, 0.831, 0.318, 1)

var current_action: ActionDef = null
var current_characters: Array[CharacterDef] = []

@onready var title_label: Label = $Margin/Layout/SlotTitle
@onready var scene_label: Label = $Margin/Layout/SceneLabel
@onready var characters_row: HBoxContainer = $Margin/Layout/CharactersRow

var _style: StyleBoxFlat
var _base_border_color: Color = COLOR_EMPTY_BORDER
var _highlighted := false


func _ready() -> void:
	title_label.text = slot_label
	_style = (get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("panel", _style)
	_refresh_visual()


func is_filled() -> bool:
	return current_action != null and not current_characters.is_empty()


func clear() -> void:
	current_action = null
	current_characters = []
	_refresh_visual()


func remove_character(character: CharacterDef) -> void:
	current_characters.erase(character)
	_refresh_visual()
	composition_changed.emit(self)


func current_shot() -> ShotElement:
	return ShotElement.new(current_characters.duplicate(), current_action)


func place(shot: ShotElement) -> void:
	current_action = shot.action
	current_characters = shot.characters.duplicate()
	_refresh_visual()
	composition_changed.emit(self)


func show_result(matched: bool) -> void:
	_base_border_color = COLOR_SUCCESS_BORDER if matched else COLOR_FAIL_BORDER
	_apply_border_color()


func set_highlighted(active: bool) -> void:
	_highlighted = active
	_apply_border_color()


func _refresh_visual() -> void:
	scene_label.text = current_action.display_name if current_action != null else "— scene —"

	for child in characters_row.get_children():
		child.queue_free()
	for character in current_characters:
		var chip_button := Button.new()
		chip_button.text = character.display_name
		chip_button.add_theme_color_override("font_color", character.portrait_color)
		chip_button.add_theme_font_size_override("font_size", 12)
		chip_button.pressed.connect(remove_character.bind(character))
		characters_row.add_child(chip_button)

	_base_border_color = COLOR_FILLED_BORDER if is_filled() else COLOR_EMPTY_BORDER
	_apply_border_color()


func _apply_border_color() -> void:
	_style.border_color = COLOR_HIGHLIGHT_BORDER if _highlighted else _base_border_color


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	match data.get("type"):
		"broadcast_scene":
			return data.get("action") is ActionDef
		"broadcast_character":
			if current_action == null:
				return false
			if current_characters.size() >= MAX_CHARACTERS:
				return false
			var character: CharacterDef = data.get("character")
			if character == null:
				return false
			for existing in current_characters:
				if existing.id == character.id:
					return false
			return true
		_:
			return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	match data.get("type"):
		"broadcast_scene":
			current_action = data["action"]
		"broadcast_character":
			current_characters.append(data["character"])
	_refresh_visual()
	composition_changed.emit(self)
