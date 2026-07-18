class_name SceneFrame
extends Control

signal eject_requested(action: ActionDef)
signal footage_ejected(action: ActionDef)

@export_range(0.0, 4.0, 0.05) var ejection_time_scale := 1.0

var current_action: ActionDef
var interaction_enabled := true
var _available_actions: Array[ActionDef] = []
var _ejected: Dictionary = {}
## action.id -> Array[Control]: every polaroid ever printed for that scene, so the
## same scene can be printed (and placed) more than once, e.g. a shot reused in
## both the CAUSE and CONFLICT frames. Placement state lives per-card as
## metadata ("placed"), not per-action, so printing one more copy of an
## already-placed scene stays independently draggable.
var _polaroids: Dictionary = {}
var _action_index := -1
var _dragged_card: Control

@onready var caption_label: Label = $CaptionLabel
@onready var click_region: Button = $Body/ClickRegion
@onready var previous_button: Button = $Body/Previous
@onready var next_button: Button = $Body/Next
@onready var screen_image: TextureRect = $Body/ScreenImage
@onready var archive_label: Label = $Body/ArchiveLabel
@onready var camera_body: TextureRect = $Body/CameraBody
@onready var body: Control = $Body
@onready var rear_ejection_layer: Control = %RearEjectionLayer
@onready var front_ejection_layer: Control = %FrontEjectionLayer


func _ready() -> void:
	click_region.pressed.connect(eject_current)
	previous_button.pressed.connect(cycle_scene.bind(-1))
	next_button.pressed.connect(cycle_scene.bind(1))


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not is_instance_valid(_dragged_card):
		return
	_dragged_card.modulate.a = 1.0
	_dragged_card = null
	_refresh_visual()


func setup(available_actions: Array[ActionDef]) -> void:
	_available_actions = available_actions
	_ejected.clear()
	for cards in _polaroids.values():
		for card in cards:
			if is_instance_valid(card):
				card.queue_free()
	_polaroids.clear()
	_action_index = 0 if not _available_actions.is_empty() else -1
	current_action = _available_actions[0] if not _available_actions.is_empty() else null
	_refresh_visual()


func cycle_scene(direction := 1) -> void:
	if _available_actions.is_empty() or not interaction_enabled:
		return
	_action_index = wrapi(_action_index + direction, 0, _available_actions.size())
	current_action = _available_actions[_action_index]
	_pulse_selector(direction)
	_refresh_visual()


func eject_current() -> void:
	if not interaction_enabled:
		return
	if current_action == null:
		cycle_scene(1)
	if current_action == null:
		return
	# Every press prints a fresh, independently-placeable copy — a scene needed in
	# more than one frame (e.g. the same "Attack" in both CAUSE and CONFLICT) can
	# be printed as many times as it's needed.
	_ejected[current_action.id] = true
	eject_requested.emit(current_action)
	footage_ejected.emit(current_action)
	_eject_polaroid(current_action)
	_refresh_visual()


## card is the specific physical polaroid being returned — with a scene now
## printable multiple times, only that instance should come back to the tray,
## not every copy of the same scene.
func return_card(action: ActionDef, card: Control = null) -> void:
	if action == null or card == null or not is_instance_valid(card):
		return
	var return_index := -1
	for index in _available_actions.size():
		if _available_actions[index].id == action.id:
			return_index = index
			break
	# Ignore cleanup signals from a report that is no longer loaded.
	if return_index < 0:
		return
	card.set_meta("placed", false)
	current_action = action
	_action_index = return_index
	_refresh_visual()
	if card.get_parent() != front_ejection_layer:
		card.reparent(front_ejection_layer, true)
	card.visible = true
	card.modulate.a = 0.0
	card.scale = Vector2(0.86, 0.86)
	var tween := create_tween().set_parallel()
	tween.tween_property(card, "modulate:a", 1.0, 0.12)
	tween.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func mark_placed(action: ActionDef, card: Control = null) -> void:
	if action == null:
		return
	if card != null and is_instance_valid(card):
		card.set_meta("placed", true)
	_refresh_visual()


func is_ejected(action: ActionDef) -> bool:
	return action != null and _ejected.has(action.id)


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	click_region.disabled = not enabled
	previous_button.disabled = not enabled
	next_button.disabled = not enabled
	for cards in _polaroids.values():
		for card in cards:
			if is_instance_valid(card):
				var control := card as Control
				control.mouse_filter = Control.MOUSE_FILTER_STOP if enabled and control.get_parent() == front_ejection_layer else Control.MOUSE_FILTER_IGNORE
	_refresh_visual()


func _refresh_visual() -> void:
	if current_action == null:
		caption_label.text = "NO CAPTURE"
		screen_image.texture = null
		archive_label.visible = false
		_show_only_polaroid(&"")
		return
	caption_label.text = current_action.display_name.to_upper()
	screen_image.texture = current_action.scene_image
	# The whole camera archives together once editing locks (BROADCAST pressed),
	# not the instant a single scene is first printed — a scene may still need
	# printing again for another frame right up until then.
	var is_archived := not interaction_enabled
	# The flat v5 camera keeps the LCD as a pure live preview. Archive state is
	# rendered beneath the hardware, never stamped over the footage itself.
	archive_label.visible = false
	if is_archived:
		caption_label.text = "ARCHIVED"
	_show_only_polaroid(current_action.id)
	click_region.tooltip_text = "Footage archived — drag a printed polaroid" if is_archived else "Eject captured footage"


func _get_drag_data(_at_position: Vector2) -> Variant:
	# The camera itself is machinery, not the draggable evidence. Footage can
	# only be moved by physically grabbing the polaroid after it is printed.
	return null


func _get_polaroid_drag_data(at_position: Vector2, action: ActionDef, card: Control, show_preview := true) -> Variant:
	if action == null or not interaction_enabled or card.get_meta("placed", false):
		return null
	current_action = action
	for index in _available_actions.size():
		if _available_actions[index].id == action.id:
			_action_index = index
			break
	_refresh_visual()
	# set_drag_preview() must happen during this callback. gui_is_dragging() only
	# becomes true after the callback returns, so guarding it suppresses the
	# physical card preview that should follow the pointer.
	if show_preview:
		card.set_drag_preview(_build_preview_for(action, at_position))
		_dragged_card = card
		card.call_deferred("set_modulate", Color(1, 1, 1, 0))
	# The specific card travels with the payload so mark_placed/return_card can
	# target this exact printed copy instead of every copy of the same scene.
	return {"type": "broadcast_scene", "action": action, "captured_card": true, "card": card}


func _build_preview_for(action: ActionDef, grab_position := Vector2(95.0, 10.0)) -> Control:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(190, 132)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e9e2d4")
	style.border_color = Color("777b82")
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 7
	style.content_margin_top = 7
	style.content_margin_right = 7
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 9
	preview.add_theme_stylebox_override("panel", style)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 3)
	preview.add_child(layout)
	var image := TextureRect.new()
	image.texture = action.scene_image
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.custom_minimum_size = Vector2(176, 96)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(image)
	var label := Label.new()
	label.text = action.display_name.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("20252b"))
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(label)
	# Godot positions drag previews from the pointer. Offset the duplicate so
	# the pointer acts like a pin through its top edge and the whole card hangs
	# below it instead of appearing as a detached badge beside the cursor.
	var pin_x := clampf(grab_position.x, 18.0, 172.0)
	preview.position = Vector2(-pin_x, 8.0)
	preview.pivot_offset = Vector2(pin_x, 0.0)
	preview.rotation = deg_to_rad(3.0 if pin_x < 95.0 else -3.0)
	preview.modulate.a = 0.98
	return preview


func _eject_polaroid(action: ActionDef) -> void:
	_pulse_camera()
	if not _polaroids.has(action.id):
		_polaroids[action.id] = []
	var stack: Array = _polaroids[action.id]
	var stack_index := stack.size()
	# A small fan-out per stacked copy so multiple prints of the same scene read
	# as a physical stack of photos rather than perfectly overlapping.
	var settle_position := Vector2(70, -104) + Vector2(stack_index * 3.0, stack_index * -2.0)
	var settle_rotation := deg_to_rad(2.0 + stack_index * 3.0)

	var card := _build_polaroid(action)
	rear_ejection_layer.add_child(card)
	stack.append(card)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = Vector2(70, 48)
	card.rotation = deg_to_rad(-1.5)
	card.modulate.a = 0.0
	card.scale = Vector2(0.96, 0.96)
	if is_zero_approx(ejection_time_scale):
		card.position = settle_position
		card.rotation = settle_rotation
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
		card.reparent(front_ejection_layer, true)
		card.mouse_filter = Control.MOUSE_FILTER_STOP if interaction_enabled else Control.MOUSE_FILTER_IGNORE
		return
	var clearance_target := Vector2(70, -83) + Vector2(stack_index * 3.0, 0.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(card, "position", clearance_target, 0.52 * ejection_time_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "rotation", deg_to_rad(0.6), 0.52 * ejection_time_scale).set_trans(Tween.TRANS_SINE)
	tween.tween_property(card, "scale", Vector2.ONE, 0.28 * ejection_time_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.08 * ejection_time_scale)
	await tween.finished
	if not is_instance_valid(card):
		return
	card.reparent(front_ejection_layer, true)
	var settle := create_tween().set_parallel()
	settle.tween_property(card, "position", settle_position, 0.16 * ejection_time_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle.tween_property(card, "rotation", settle_rotation, 0.16 * ejection_time_scale).set_trans(Tween.TRANS_SINE)
	await settle.finished
	if is_instance_valid(card):
		card.mouse_filter = Control.MOUSE_FILTER_STOP if interaction_enabled else Control.MOUSE_FILTER_IGNORE


func _build_polaroid(action: ActionDef) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(190, 132)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = Vector2(95, 126)
	card.tooltip_text = "Drag this archived footage into a frame"
	card.set_drag_forwarding(_get_polaroid_drag_data.bind(action, card), Callable(), Callable())
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("e9e2d4")
	paper.border_color = Color("777b82")
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(4)
	paper.content_margin_left = 7
	paper.content_margin_top = 7
	paper.content_margin_right = 7
	paper.content_margin_bottom = 8
	paper.shadow_color = Color(0, 0, 0, 0.58)
	paper.shadow_size = 7
	card.add_theme_stylebox_override("panel", paper)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 3)
	card.add_child(layout)
	var photo := TextureRect.new()
	photo.texture = action.scene_image
	photo.custom_minimum_size = Vector2(176, 96)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(photo)
	var label := Label.new()
	label.text = action.display_name.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("20252b"))
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(label)
	return card


func _show_only_polaroid(action_id: StringName) -> void:
	for id in _polaroids:
		var cards: Array = _polaroids[id]
		for card in cards:
			if is_instance_valid(card):
				card.visible = id == action_id and not card.get_meta("placed", false)


func _pulse_camera() -> void:
	var start := body.position
	var tween := create_tween()
	tween.tween_property(body, "position", start + Vector2(0, 6), 0.06)
	tween.tween_property(body, "position", start, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pulse_selector(direction: int) -> void:
	var start := camera_body.position
	var offset := Vector2(signf(direction) * 3.0, 0)
	var tween := create_tween().set_parallel()
	tween.tween_property(camera_body, "position", start + offset, 0.045)
	tween.chain().tween_property(camera_body, "position", start, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var screen_tween := create_tween()
	screen_tween.tween_property(screen_image, "modulate", Color(1.22, 1.28, 1.32, 1), 0.04)
	screen_tween.tween_property(screen_image, "modulate", Color.WHITE, 0.13)
