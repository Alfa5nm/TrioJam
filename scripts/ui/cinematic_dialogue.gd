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

var is_presenting := false
var _skip_requested := false
var _advance_requested := false
var _typing := false
var _last_blip_time := -10.0
var _presentation_id := 0
var _speaker: Node2D
var _screen_anchor := Vector2.ZERO
var _uses_screen_anchor := false

@onready var dialogue: Control = $Dialogue
@onready var bubble: Control = $Dialogue/Bubble
@onready var panel: PanelContainer = $Dialogue/Bubble/Panel
@onready var line: Label = $Dialogue/Bubble/Panel/Margin/Line
@onready var continue_cue: Label = $Dialogue/Bubble/ContinueCue
@onready var chapter: Control = $Chapter
@onready var chapter_title: Label = $Chapter/Title
@onready var chapter_rule: ColorRect = $Chapter/Rule
@onready var blip: AudioStreamPlayer = $Blip


func _ready() -> void:
	dialogue.visible = false
	chapter.visible = false
	continue_cue.visible = false


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
	_speaker = speaker
	_uses_screen_anchor = false
	await _show_line(text, hold_seconds, manual_advance)


func show_line_at(text: String, screen_position: Vector2, hold_seconds := 1.15, manual_advance := false) -> void:
	_speaker = null
	_screen_anchor = screen_position
	_uses_screen_anchor = true
	await _show_line(text, hold_seconds, manual_advance)


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

	continue_cue.visible = true
	var cue_tween := create_tween().set_loops()
	cue_tween.tween_property(continue_cue, "modulate:a", 0.28, _duration(0.42))
	cue_tween.tween_property(continue_cue, "modulate:a", 0.9, _duration(0.42))
	if manual_advance:
		await _wait_for_advance(presentation_id)
	else:
		await _wait(hold_seconds)
	if presentation_id != _presentation_id:
		return
	if cue_tween.is_running():
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


func _place_bubble() -> void:
	var anchor := Vector2(get_viewport().get_visible_rect().size.x * 0.5, 650.0)
	if _uses_screen_anchor:
		anchor = _screen_anchor
	elif is_instance_valid(_speaker):
		anchor = get_viewport().get_canvas_transform() * _speaker.global_position + speaker_offset
	var viewport_size := get_viewport().get_visible_rect().size
	var desired := anchor - Vector2(bubble.size.x * 0.5, bubble.size.y)
	desired.x = clampf(desired.x, 18.0, viewport_size.x - bubble.size.x - 18.0)
	desired.y = clampf(desired.y, 68.0, viewport_size.y - bubble.size.y - 24.0)
	bubble.position = desired.round()


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
