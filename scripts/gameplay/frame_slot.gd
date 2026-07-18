class_name FrameSlot
extends Control

signal composition_changed(slot: FrameSlot)
signal capacity_warning(slot: FrameSlot)
## card is the specific physical polaroid this footage came from (null when
## placed programmatically via place(), not by dragging one) — lets the same
## scene be printed and placed more than once without cards colliding.
signal footage_removed(action: ActionDef, card: Control)
signal footage_placed(action: ActionDef, card: Control)

@export var slot_label := "CAUSE"

## Effective cap: current_action.max_characters once a scene is placed, otherwise
## _default_max_characters (the report's own max_characters_per_frame). Kept as a
## plain var (not computed on read) since _can_drop_data/capacity_warning read it
## directly; _update_capacity_for_action() keeps it in sync whenever current_action changes.
var max_characters := 2
var _default_max_characters := 2

const COLOR_EMPTY_BORDER := Color(0.71, 0.745, 0.81, 0)
const COLOR_FILLED_BORDER := Color(0.78, 0.81, 0.85, 0.9)
const COLOR_SUCCESS_BORDER := Color(0.294, 0.812, 0.49, 1)
const COLOR_FAIL_BORDER := Color(0.714, 0.275, 0.310, 1)
const COLOR_HIGHLIGHT_BORDER := Color(0.976, 0.831, 0.318, 1)
const COLOR_TRUTH_REJECTED_BORDER := Color(0.38, 0.7, 0.96, 1)
const FRAME_SIZE := Vector2(256, 193)
const SCENE_ZOOM := 1.15
const SCENE_PAN_BIAS := 0.15 # 0 = crop window flush left (content shifts right), 1 = flush right

var current_action: ActionDef = null
var current_characters: Array[CharacterDef] = []
var current_scene_card: Control = null
var interaction_enabled := true

@onready var state_overlay: Panel = $StateOverlay
@onready var scene_image: TextureRect = $SceneImage
@onready var title_label: Label = $ContentMargin/Layout/SlotTitle
@onready var scene_label: Label = $ContentMargin/Layout/SceneLabel
@onready var characters_row: HBoxContainer = $ContentMargin/Layout/CharactersRow
@onready var return_button: Button = $ReturnButton

var _style: StyleBoxFlat
var _base_border_color: Color = COLOR_EMPTY_BORDER
var _highlighted := false


func _ready() -> void:
	# Each frame's painted border in the console art is a slightly different width,
	# so the slot's rect is authored per-instance (and normalized by the interface).
	# Do not clamp it to a single FRAME_SIZE here or the footage stops short of the
	# border on the wider frames.
	pivot_offset = size * 0.5
	title_label.text = slot_label
	_style = (state_overlay.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	state_overlay.add_theme_stylebox_override("panel", _style)
	_refresh_visual()
	# SceneImage is a purely visual child. Keeping it mouse-active makes Godot
	# choose it as the drop target once footage is visible, bypassing this
	# FrameSlot's _can_drop_data/_drop_data methods.
	scene_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return_button.pressed.connect(remove_footage)
	gui_input.connect(_on_frame_input)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func is_filled() -> bool:
	return current_action != null and not current_characters.is_empty()


## Sets the fallback cap used while no scene is placed yet. Called once when a
## report loads (report.max_characters_per_frame); does not affect a slot that
## already has a scene placed, since that scene's own cap takes over.
func set_default_max_characters(value: int) -> void:
	_default_max_characters = value
	_update_capacity_for_action()


func _update_capacity_for_action() -> void:
	max_characters = current_action.max_characters if current_action != null else _default_max_characters
	# A scene swap or removal can drop the cap below what's already placed —
	# trim from the end rather than leaving an over-full slot silently invalid.
	while current_characters.size() > max_characters:
		current_characters.pop_back()


func clear() -> void:
	var removed := current_action
	var removed_card := current_scene_card
	current_action = null
	current_scene_card = null
	current_characters = []
	_update_capacity_for_action()
	hide_scene_reveal()
	_refresh_visual()
	if removed != null:
		footage_removed.emit(removed, removed_card)


func remove_footage() -> void:
	if not interaction_enabled or current_action == null:
		return
	var removed := current_action
	var removed_card := current_scene_card
	current_action = null
	current_scene_card = null
	_update_capacity_for_action()
	hide_scene_reveal()
	_refresh_visual()
	footage_removed.emit(removed, removed_card)
	composition_changed.emit(self)


func show_scene_reveal(texture: Texture2D) -> void:
	scene_image.texture = _build_panned_scene_texture(texture)
	scene_image.visible = true
	scene_label.visible = false


func _build_panned_scene_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var source_size := source.get_size()
	var frame_size := size if size.x > 1.0 and size.y > 1.0 else FRAME_SIZE
	var target_ratio := frame_size.x / frame_size.y
	var crop_height := source_size.y / SCENE_ZOOM
	var crop_width := crop_height * target_ratio
	if crop_width > source_size.x:
		crop_width = source_size.x
		crop_height = crop_width / target_ratio
	var max_offset := Vector2(source_size.x - crop_width, source_size.y - crop_height)
	var region := Rect2(max_offset.x * SCENE_PAN_BIAS, max_offset.y * 0.5, crop_width, crop_height)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	return atlas


func hide_scene_reveal() -> void:
	scene_image.visible = false
	scene_label.visible = true


func remove_character(character: CharacterDef) -> void:
	if not interaction_enabled:
		return
	current_characters.erase(character)
	_refresh_visual()
	composition_changed.emit(self)


func current_shot() -> ShotElement:
	return ShotElement.new(current_characters.duplicate(), current_action)


func place(shot: ShotElement) -> void:
	if current_action != null and current_action != shot.action:
		footage_removed.emit(current_action, current_scene_card)
	current_action = shot.action
	# Programmatic placement (tests, data-driven setup) has no physical card.
	current_scene_card = null
	current_characters = shot.characters.duplicate()
	_update_capacity_for_action()
	_refresh_visual()
	if current_action != null:
		footage_placed.emit(current_action, null)
	composition_changed.emit(self)


func show_result(matched: bool) -> void:
	_base_border_color = COLOR_SUCCESS_BORDER if matched else COLOR_FAIL_BORDER
	_apply_border_color()


func show_truth_rejected() -> void:
	_base_border_color = COLOR_TRUTH_REJECTED_BORDER
	_apply_border_color()


func set_highlighted(active: bool) -> void:
	_highlighted = active
	_apply_border_color()


func _refresh_visual() -> void:
	scene_label.text = current_action.display_name if current_action != null else "— scene —"
	return_button.visible = current_action != null and interaction_enabled
	if current_action != null and current_action.scene_image != null:
		scene_image.texture = _build_panned_scene_texture(current_action.scene_image)
		scene_image.visible = true
		# Always caption the scene, even over a photo — some placeholder scenes
		# currently share the exact same image (e.g. Licensing Seeds and Arrest),
		# so the name is the only way to tell them apart once dropped in a frame.
		scene_label.visible = true
	else:
		scene_image.texture = null
		scene_image.visible = false
		scene_label.visible = current_action == null or current_action.scene_image == null

	for child in characters_row.get_children():
		child.queue_free()
	for character in current_characters:
		var chip_button := TextureButton.new()
		chip_button.custom_minimum_size = Vector2(64, 64)
		chip_button.texture_normal = character.get_display_texture()
		chip_button.ignore_texture_size = true
		chip_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		chip_button.tooltip_text = character.display_name + " (click to remove)"
		chip_button.disabled = not interaction_enabled
		chip_button.pressed.connect(remove_character.bind(character))
		characters_row.add_child(chip_button)

	_base_border_color = COLOR_FILLED_BORDER if is_filled() else COLOR_EMPTY_BORDER
	_apply_border_color()


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	return_button.disabled = not enabled
	return_button.visible = enabled and current_action != null
	for child in characters_row.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = not enabled


func _apply_border_color() -> void:
	_style.border_color = COLOR_HIGHLIGHT_BORDER if _highlighted else _base_border_color


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not interaction_enabled:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	match data.get("type"):
		"broadcast_scene":
			return data.get("action") is ActionDef
		"broadcast_character":
			if current_characters.size() >= max_characters:
				capacity_warning.emit(self)
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
			if current_action != null and current_action != data["action"]:
				footage_removed.emit(current_action, current_scene_card)
			current_action = data["action"]
			current_scene_card = data.get("card")
			_update_capacity_for_action()
			footage_placed.emit(current_action, current_scene_card)
		"broadcast_character":
			current_characters.append(data["character"])
	_refresh_visual()
	_play_drop_feedback()
	composition_changed.emit(self)


func _on_frame_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		remove_footage()


func _on_hover(active: bool) -> void:
	if not interaction_enabled:
		return
	# Keep all three trays geometrically identical. Hovering brightens a tray
	# instead of scaling it beyond the neighbouring frame bounds.
	scale = Vector2.ONE
	var target := Color(1.08, 1.08, 1.08, 1) if active else Color.WHITE
	create_tween().tween_property(self, "self_modulate", target, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_drop_feedback() -> void:
	scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(self, "self_modulate", Color(1.2, 1.2, 1.2, 1), 0.05)
	tween.tween_property(self, "self_modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
