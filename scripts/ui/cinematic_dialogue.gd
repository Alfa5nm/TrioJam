class_name CinematicDialogue
extends CanvasLayer

signal line_started(text: String)
signal line_finished(text: String)

@export_range(8.0, 80.0, 1.0) var characters_per_second := 32.0
@export_range(0.0, 1.0, 0.01) var punctuation_pause := 0.12
@export_range(0.01, 0.25, 0.01) var blip_interval := 0.055
@export_range(0.01, 1.0, 0.01) var timing_scale := 1.0
@export var instant_mode := false
@export var speaker_offset := Vector2(0.0, -205.0)
@export_range(320.0, 920.0, 10.0) var standard_width := 430.0
@export_range(18, 34, 1) var standard_font_size := 31
@export_range(24.0, 90.0, 1.0) var standard_characters_per_line := 34.0
@export_range(24.0, 42.0, 1.0) var standard_line_height := 34.0
@export var bark_speaker_offset := Vector2(0.0, -12.0)
@export_range(0.0, 1.0, 0.01) var bark_parallax_strength := 0.94
@export_range(320.0, 680.0, 10.0) var bark_width := 460.0
@export_range(18, 34, 1) var bark_font_size := 27
@export_range(18, 34, 1) var bark_long_font_size := 25
@export_range(24.0, 64.0, 1.0) var bark_characters_per_line := 32.0
@export_range(22.0, 42.0, 1.0) var bark_line_height := 31.0

var is_presenting := false
var _skip_requested := false
var _advance_requested := false
var _typing := false
var _last_blip_time := -10.0
var _presentation_id := 0
var _speaker: Node2D
var _screen_anchor := Vector2.ZERO
var _uses_screen_anchor := false
var _show_continue_cue := true
var _default_blip_stream: AudioStream
var _uses_parallax_anchor := false
var _parallax_anchor_initialized := false
var _parallax_anchor_origin := Vector2.ZERO
var _bubble_horizontal_bias := 0.0
var _default_panel_style: StyleBoxFlat
var _default_line_color := Color.WHITE
var _default_tail_color := Color(0.0431373, 0.113725, 0.301961, 0.96)

const SOLDIER_TEXT_COLOR := Color(1.0, 0.31, 0.28, 1.0)
const SOLDIER_BORDER_COLOR := Color(0.95, 0.18, 0.2, 0.98)
const CIVILIAN_TEXT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const CIVILIAN_BORDER_COLOR := Color(0.82, 0.92, 1.0, 0.98)
const MC_TEXT_COLOR := Color(0.78, 0.91, 1.0, 1.0)
const REPRESENTATIVE_TEXT_COLOR := Color(0.42, 0.94, 1.0, 1.0)
const REPRESENTATIVE_BORDER_COLOR := Color(0.1, 0.78, 0.94, 0.98)
const OPPOSITION_TEXT_COLOR := Color(1.0, 0.78, 0.32, 1.0)
const OPPOSITION_BORDER_COLOR := Color(0.94, 0.52, 0.12, 0.98)

@onready var dialogue: Control = $Dialogue
@onready var bubble: Control = $Dialogue/Bubble
@onready var tail: Polygon2D = $Dialogue/Bubble/Tail
@onready var panel: PanelContainer = $Dialogue/Bubble/Panel
@onready var margin: VBoxContainer = $Dialogue/Bubble/Panel/Margin
@onready var line: Label = $Dialogue/Bubble/Panel/Margin/Line
@onready var speaker_label: Label = $Dialogue/Bubble/Panel/Margin/SpeakerLabel
@onready var continue_cue: Label = $Dialogue/Bubble/ContinueCue
@onready var chapter: Control = $Chapter
@onready var chapter_title: Label = $Chapter/Title
@onready var chapter_rule: ColorRect = $Chapter/Rule
@onready var blip: AudioStreamPlayer = $Blip


func _ready() -> void:
	_default_blip_stream = blip.stream
	var initial_style := panel.get_theme_stylebox(&"panel")
	if initial_style is StyleBoxFlat:
		_default_panel_style = (initial_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	_default_line_color = line.get_theme_color(&"font_color")
	_default_tail_color = tail.color
	dialogue.visible = false
	chapter.visible = false
	continue_cue.visible = false
	speaker_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_presenting:
		return
	if event.is_action_pressed(&"interact") or (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	):
		if _typing:
			_skip_requested = true
		else:
			_advance_requested = true
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if is_presenting:
		_place_bubble()


func show_chapter(title: String, duration := 1.25) -> void:
	chapter_title.text = title
	chapter.visible = true
	chapter.modulate.a = 0.0
	chapter_title.position.x = -12.0
	chapter_rule.scale.x = 0.0
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(chapter, "modulate:a", 1.0, _duration(0.32))
	reveal.tween_property(chapter_title, "position:x", 0.0, _duration(0.42)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(chapter_rule, "scale:x", 1.0, _duration(0.52)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await reveal.finished
	await _wait(duration)
	var dismiss := create_tween()
	dismiss.tween_property(chapter, "modulate:a", 0.0, _duration(0.3))
	await dismiss.finished
	chapter.visible = false


func show_line(text: String, hold_seconds := 1.15, speaker: Node2D = null, manual_advance := false) -> void:
	_configure_standard_line(text)
	_speaker = speaker
	_uses_screen_anchor = false
	_uses_parallax_anchor = false
	await _show_line(text, hold_seconds, manual_advance)


func show_line_at(text: String, screen_position: Vector2, hold_seconds := 1.15, manual_advance := false) -> void:
	_configure_standard_line(text)
	_speaker = null
	_screen_anchor = screen_position
	_uses_screen_anchor = true
	_uses_parallax_anchor = false
	await _show_line(text, hold_seconds, manual_advance)


func show_bark(
		text: String,
		speaker_name: String,
		speaker: Node2D,
		hold_seconds := 1.15,
		blip_stream: AudioStream = null
	) -> void:
	_configure_ambient_bark(speaker_name, text, blip_stream)
	_speaker = speaker
	_uses_screen_anchor = false
	_uses_parallax_anchor = true
	_parallax_anchor_initialized = false
	await _show_line(text, hold_seconds, false)
	_configure_standard_line()


func _show_line(text: String, hold_seconds: float, manual_advance: bool) -> void:
	_presentation_id += 1
	var presentation_id := _presentation_id
	is_presenting = true
	_skip_requested = false
	_advance_requested = false
	var display_text := text.replace("…", "...")
	line.text = display_text
	line.visible_characters = 0
	continue_cue.visible = false
	dialogue.visible = true
	bubble.modulate.a = 0.0
	bubble.pivot_offset = bubble.size * 0.5
	bubble.scale = Vector2(0.94, 0.94)
	_place_bubble()
	line_started.emit(text)

	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(bubble, "modulate:a", 1.0, _duration(0.16))
	reveal.tween_property(bubble, "scale", Vector2.ONE, _duration(0.22)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await reveal.finished
	if presentation_id != _presentation_id:
		return

	if instant_mode:
		line.visible_characters = -1
	else:
		await _type_line(display_text, presentation_id)
	if presentation_id != _presentation_id:
		return

	continue_cue.visible = _show_continue_cue
	var cue_tween: Tween
	if _show_continue_cue:
		cue_tween = create_tween().set_loops()
		cue_tween.tween_property(continue_cue, "modulate:a", 0.28, _duration(0.42))
		cue_tween.tween_property(continue_cue, "modulate:a", 0.9, _duration(0.42))
	if manual_advance:
		await _wait_for_advance(presentation_id)
	else:
		await _wait(hold_seconds)
	if presentation_id != _presentation_id:
		return
	if cue_tween != null and cue_tween.is_running():
		cue_tween.kill()

	var dismiss := create_tween()
	dismiss.tween_property(bubble, "modulate:a", 0.0, _duration(0.14))
	await dismiss.finished
	dialogue.visible = false
	is_presenting = false
	line_finished.emit(text)


func hide_immediately() -> void:
	_presentation_id += 1
	_skip_requested = true
	_advance_requested = true
	_typing = false
	is_presenting = false
	dialogue.visible = false
	chapter.visible = false
	blip.stop()
	_speaker = null
	_uses_screen_anchor = false
	_uses_parallax_anchor = false
	_parallax_anchor_initialized = false


func _place_bubble() -> void:
	var anchor := Vector2(get_viewport().get_visible_rect().size.x * 0.5, 650.0)
	if _uses_screen_anchor:
		anchor = _screen_anchor
	elif is_instance_valid(_speaker):
		var active_offset := bark_speaker_offset if _uses_parallax_anchor else speaker_offset
		var current_speaker_anchor := get_viewport().get_canvas_transform() * _speaker.global_position + active_offset
		if _uses_parallax_anchor:
			if not _parallax_anchor_initialized:
				_parallax_anchor_origin = current_speaker_anchor
				_parallax_anchor_initialized = true
			anchor = _parallax_anchor_origin + (current_speaker_anchor - _parallax_anchor_origin) * bark_parallax_strength
		else:
			anchor = current_speaker_anchor
	var viewport_size := get_viewport().get_visible_rect().size
	var desired := anchor - Vector2(bubble.size.x * 0.5, bubble.size.y)
	desired.x += _bubble_horizontal_bias
	desired.x = clampf(desired.x, 18.0, viewport_size.x - bubble.size.x - 18.0)
	desired.y = clampf(desired.y, 68.0, viewport_size.y - bubble.size.y - 24.0)
	bubble.position = desired.round()
	# Keep the pointer attached to the speaker when the bubble is clamped away
	# from its ideal centered position near either edge of the screen.
	var local_pointer_x := clampf(anchor.x - bubble.position.x, 28.0, bubble.size.x - 28.0)
	tail.position = Vector2(local_pointer_x - bubble.size.x * 0.5, panel.size.y - 72.0)


func _type_line(text: String, presentation_id: int) -> void:
	_typing = true
	var character_delay := 1.0 / characters_per_second
	for index in text.length():
		if presentation_id != _presentation_id:
			_typing = false
			return
		if _skip_requested:
			line.visible_characters = -1
			_skip_requested = false
			_typing = false
			return
		line.visible_characters = index + 1
		var character := text.substr(index, 1)
		if not character.strip_edges().is_empty() and character not in ".,…!?—-":
			_play_blip()
		var delay := character_delay
		if character in ".,…!?":
			delay += punctuation_pause
		await get_tree().create_timer(_duration(delay)).timeout
	_typing = false


func _wait_for_advance(presentation_id: int) -> void:
	if instant_mode:
		await get_tree().process_frame
		return
	while presentation_id == _presentation_id and not _advance_requested:
		await get_tree().process_frame
	_advance_requested = false


func _play_blip() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_blip_time < blip_interval:
		return
	_last_blip_time = now
	blip.pitch_scale = randf_range(0.96, 1.035)
	blip.play()


func _configure_standard_line(text := "") -> void:
	_reset_speaker_style()
	_show_continue_cue = true
	speaker_label.visible = false
	speaker_label.text = ""
	blip.stream = _default_blip_stream
	var estimated_lines := maxi(1, ceili(float(text.length()) / standard_characters_per_line))
	var panel_height := maxf(72.0, 20.0 + float(estimated_lines) * standard_line_height)
	bubble.size = Vector2(standard_width, panel_height + 14.0)
	panel.custom_minimum_size = Vector2(standard_width, panel_height)
	panel.size = Vector2(standard_width, panel_height)
	margin.add_theme_constant_override(&"separation", 0)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2.ZERO
	line.custom_minimum_size = Vector2(0.0, panel_height - 20.0)
	line.add_theme_font_size_override(&"font_size", standard_font_size)
	continue_cue.position = Vector2(standard_width - 29.0, panel_height - 26.0)


func _configure_ambient_bark(speaker_name: String, text: String, blip_stream: AudioStream) -> void:
	_apply_speaker_style(speaker_name)
	_show_continue_cue = false
	speaker_label.text = ""
	speaker_label.visible = false
	blip.stream = blip_stream if blip_stream != null else _default_blip_stream
	var long_line := text.length() > 58
	var estimated_lines := ceili(float(text.length()) / bark_characters_per_line)
	var panel_height := maxf(82.0, 20.0 + float(estimated_lines) * bark_line_height)
	bubble.size = Vector2(bark_width, panel_height + 14.0)
	panel.custom_minimum_size = Vector2(bark_width, panel_height)
	panel.size = Vector2(bark_width, panel_height)
	margin.add_theme_constant_override(&"separation", 0)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(0.0, panel_height - 20.0)
	line.add_theme_font_size_override(&"font_size", bark_long_font_size if long_line else bark_font_size)


func _apply_speaker_style(speaker_name: String) -> void:
	var text_color := CIVILIAN_TEXT_COLOR
	var border_color := CIVILIAN_BORDER_COLOR
	_bubble_horizontal_bias = 0.0
	match speaker_name:
		"Soldier":
			text_color = SOLDIER_TEXT_COLOR
			border_color = SOLDIER_BORDER_COLOR
			_bubble_horizontal_bias = -78.0
		"Civilian":
			text_color = CIVILIAN_TEXT_COLOR
			border_color = CIVILIAN_BORDER_COLOR
			_bubble_horizontal_bias = 78.0
		"Civilian Customer", "Crowd":
			text_color = CIVILIAN_TEXT_COLOR
			border_color = CIVILIAN_BORDER_COLOR
			_bubble_horizontal_bias = 64.0
		"REP", "Company Representative":
			text_color = REPRESENTATIVE_TEXT_COLOR
			border_color = REPRESENTATIVE_BORDER_COLOR
		"Farmers", "Opposition Volunteer", "Opposition":
			text_color = OPPOSITION_TEXT_COLOR
			border_color = OPPOSITION_BORDER_COLOR
			_bubble_horizontal_bias = -54.0
		"MC":
			text_color = MC_TEXT_COLOR
			border_color = Color(0.32, 0.72, 1.0, 0.98)
		_:
			if not speaker_name.begins_with("Civilian"):
				text_color = CIVILIAN_TEXT_COLOR
				border_color = Color(0.24, 0.82, 1.0, 0.96)
	line.add_theme_color_override(&"font_color", text_color)
	if _default_panel_style != null:
		var speaker_style := _default_panel_style.duplicate() as StyleBoxFlat
		speaker_style.border_color = border_color
		speaker_style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.22)
		panel.add_theme_stylebox_override(&"panel", speaker_style)
		tail.color = speaker_style.bg_color


func _reset_speaker_style() -> void:
	_bubble_horizontal_bias = 0.0
	line.add_theme_color_override(&"font_color", _default_line_color)
	if _default_panel_style != null:
		panel.add_theme_stylebox_override(&"panel", _default_panel_style.duplicate())
	tail.color = _default_tail_color


func _wait(seconds: float) -> void:
	if instant_mode:
		await get_tree().process_frame
		return
	var remaining := _duration(seconds)
	while remaining > 0.0 and not _skip_requested:
		var slice := minf(remaining, 0.05)
		await get_tree().create_timer(slice).timeout
		remaining -= slice
	_skip_requested = false


func _duration(seconds: float) -> float:
	return maxf(seconds * timing_scale, 0.001)
