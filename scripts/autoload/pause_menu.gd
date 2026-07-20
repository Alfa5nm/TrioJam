extends CanvasLayer

signal pause_opened(objective: String)
signal pause_closed

const MAIN_MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const MENU_FONT := preload("res://assets/fonts/Newsreader.ttf")
const HEADING_FONT := preload("res://assets/fonts/DiarioDeAndy.otf")
const UI_BLIP := preload("res://assets/audio/ui/dialogue-blip.ogg")

var overlay: Control
var panel: PanelContainer
var objective_label: Label
var resume_button: Button
var main_menu_button: Button
var navigate_audio: AudioStreamPlayer
var _button_tweens: Dictionary = {}


func _ready() -> void:
	layer = 220
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	overlay.visible = false


func _input(event: InputEvent) -> void:
	if not (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
		return
	if event is InputEventKey and event.echo:
		return
	if overlay.visible:
		close_pause_menu()
	elif _can_pause():
		open_pause_menu()
	else:
		return
	get_viewport().set_input_as_handled()


func open_pause_menu() -> void:
	if overlay.visible or not _can_pause():
		return
	var scene_path := _current_scene_path()
	var objective := _resolve_live_objective(scene_path)
	objective_label.text = objective
	overlay.visible = true
	overlay.modulate.a = 0.0
	panel.scale = Vector2(0.965, 0.965)
	panel.pivot_offset = panel.size * 0.5
	get_tree().paused = true
	var reveal := create_tween().set_parallel(true)
	reveal.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_property(overlay, "modulate:a", 1.0, 0.16)
	reveal.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	resume_button.grab_focus()
	pause_opened.emit(objective)


func close_pause_menu() -> void:
	if not overlay.visible:
		return
	overlay.visible = false
	get_tree().paused = false
	pause_closed.emit()


func _return_to_main_menu() -> void:
	close_pause_menu()
	var transition := get_node_or_null("/root/SceneTransition")
	if transition != null and transition.has_method(&"transition_to"):
		transition.transition_to(MAIN_MENU_SCENE, false)
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _can_pause() -> bool:
	var scene_path := _current_scene_path()
	if scene_path.is_empty() or scene_path == MAIN_MENU_SCENE:
		return false
	var transition := get_node_or_null("/root/SceneTransition")
	return transition == null or not bool(transition.get("busy"))


func _current_scene_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene != null else ""


func _resolve_live_objective(scene_path: String) -> String:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method(&"get_pause_objective"):
		var live_objective: String = str(scene.call(&"get_pause_objective")).strip_edges()
		if not live_objective.is_empty():
			return live_objective
	if scene_path == "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn" and scene != null:
		return _day1_scene_objective(scene)
	return _session().get_current_objective(scene_path)


func _day1_scene_objective(scene: Node) -> String:
	var checkpoint_encounter := scene.get_node_or_null("CheckpointConfrontation")
	var seedless_rally := scene.get_node_or_null("Day1SeedlessRally")
	var broadcast_exit := scene.get_node_or_null("BroadcastRoomExit")
	if broadcast_exit != null and bool(broadcast_exit.get("is_armed")):
		return "Enter the Broadcast Room and assemble your reports."
	if seedless_rally != null and bool(seedless_rally.get("has_triggered")):
		return "Record the Seedless rally and its consequences."
	if checkpoint_encounter != null and bool(checkpoint_encounter.get("has_triggered")):
		return "Keep moving toward the grain depot."
	return "Walk toward the grain depot and observe the street."


func _build_interface() -> void:
	overlay = Control.new()
	overlay.name = "PauseOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.004, 0.006, 0.016, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var left_rule := ColorRect.new()
	left_rule.name = "AccentRule"
	left_rule.anchor_left = 0.5
	left_rule.anchor_top = 0.5
	left_rule.anchor_right = 0.5
	left_rule.anchor_bottom = 0.5
	left_rule.offset_left = -310.0
	left_rule.offset_top = -260.0
	left_rule.offset_right = -305.0
	left_rule.offset_bottom = 260.0
	left_rule.color = Color(1.0, 0.08, 0.34, 0.9)
	overlay.add_child(left_rule)

	panel = PanelContainer.new()
	panel.name = "PausePanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -305.0
	panel.offset_top = -260.0
	panel.offset_right = 305.0
	panel.offset_bottom = 260.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "BROADCAST INTERRUPTED"
	eyebrow.add_theme_font_override("font", MENU_FONT)
	eyebrow.add_theme_font_size_override("font_size", 15)
	eyebrow.add_theme_color_override("font_color", Color(1.0, 0.24, 0.44, 0.95))
	content.add_child(eyebrow)

	var heading := Label.new()
	heading.text = "PAUSED"
	heading.add_theme_font_override("font", HEADING_FONT)
	heading.add_theme_font_size_override("font_size", 46)
	heading.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	content.add_child(heading)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.color = Color(0.12, 0.75, 1.0, 0.55)
	content.add_child(rule)

	var objective_title := Label.new()
	objective_title.text = "CURRENT OBJECTIVE"
	objective_title.add_theme_font_override("font", MENU_FONT)
	objective_title.add_theme_font_size_override("font_size", 15)
	objective_title.add_theme_color_override("font_color", Color(0.42, 0.82, 1.0, 0.95))
	content.add_child(objective_title)

	objective_label = Label.new()
	objective_label.name = "Objective"
	objective_label.custom_minimum_size = Vector2(0.0, 78.0)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_override("font", MENU_FONT)
	objective_label.add_theme_font_size_override("font_size", 24)
	objective_label.add_theme_color_override("font_color", Color(0.94, 0.95, 1.0, 1.0))
	content.add_child(objective_label)

	resume_button = _make_button("RESUME")
	resume_button.name = "ResumeButton"
	resume_button.pressed.connect(close_pause_menu)
	content.add_child(resume_button)

	main_menu_button = _make_button("RETURN TO MAIN MENU")
	main_menu_button.name = "MainMenuButton"
	main_menu_button.pressed.connect(_return_to_main_menu)
	content.add_child(main_menu_button)

	var hint := Label.new()
	hint.text = "ESC  RESUME"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_override("font", MENU_FONT)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.58, 0.62, 0.74, 0.82))
	content.add_child(hint)

	navigate_audio = AudioStreamPlayer.new()
	navigate_audio.name = "Navigate"
	navigate_audio.stream = UI_BLIP
	navigate_audio.volume_db = -15.0
	navigate_audio.bus = &"UI"
	add_child(navigate_audio)


func _make_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0.0, 52.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.94, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.9, 0.94, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.015, 0.025, 0.06, 0.58), Color(0.22, 0.5, 0.7, 0.25), 2))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.12, 0.018, 0.07, 0.9), Color(1.0, 0.12, 0.42, 0.9), 5))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.12, 0.018, 0.07, 0.9), Color(1.0, 0.12, 0.42, 0.9), 5))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.02, 0.12, 0.19, 0.95), Color(0.08, 0.8, 1.0, 1.0), 5))
	button.mouse_entered.connect(_animate_button.bind(button, true))
	button.mouse_exited.connect(_animate_button.bind(button, false))
	button.focus_entered.connect(_animate_button.bind(button, true))
	button.focus_exited.connect(_animate_button.bind(button, false))
	return button


func _animate_button(button: Button, active: bool) -> void:
	if _button_tweens.has(button) and is_instance_valid(_button_tweens[button]):
		(_button_tweens[button] as Tween).kill()
	var tween := create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_button_tweens[button] = tween
	tween.tween_property(button, "modulate", Color(1.08, 1.02, 1.06, 1.0) if active else Color.WHITE, 0.12)
	if active:
		navigate_audio.pitch_scale = randf_range(0.96, 1.04)
		navigate_audio.play()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.012, 0.034, 0.975)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.1, 0.68, 0.95, 0.62)
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.74)
	style.shadow_size = 28
	return style


func _button_style(background: Color, border: Color, left_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 24.0
	style.content_margin_right = 18.0
	style.bg_color = background
	style.border_width_left = left_width
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	return style


func _session() -> Node:
	return get_node("/root/GameSession")
