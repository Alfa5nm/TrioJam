class_name Day2CinematicOverlay
extends CanvasLayer

signal frame_started(frame_id: StringName)
signal line_started(speaker: StringName, text: String)
signal frame_finished(frame_id: StringName)

@export_range(8.0, 60.0, 1.0) var characters_per_second := 25.0
@export_range(0.1, 2.0, 0.05) var timing_scale := 1.0
@export var instant_mode := false

var active := false
var _typing := false
var _skip_requested := false

@onready var root: Control = $Root
@onready var image: TextureRect = $Root/Image
@onready var chrome: Control = $Root/CameraChrome
@onready var flash: ColorRect = $Root/Flash
@onready var caption: PanelContainer = $Root/Caption
@onready var caption_text: Label = $Root/Caption/Margin/Text
@onready var camera_click: AudioStreamPlayer = $CameraClick
@onready var blip: AudioStreamPlayer = $Blip


func _ready() -> void:
	visible = true
	root.visible = false
	caption.visible = false
	flash.modulate.a = 0.0


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed(&"interact") or (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	):
		if _typing:
			_skip_requested = true
		get_viewport().set_input_as_handled()


func show_frame(
		frame_id: StringName,
		texture: Texture2D,
		lines: Array[Dictionary],
		camera_mode := true,
		initial_flash := true
	) -> void:
	visible = true
	active = true
	root.visible = true
	image.texture = texture
	chrome.visible = camera_mode
	caption.visible = false
	frame_started.emit(frame_id)
	if camera_mode:
		camera_click.play()
	if initial_flash:
		await _flash()
	for beat in lines:
		await _show_caption(
			StringName(beat.get("speaker", &"")),
			str(beat.get("text", "")),
			StringName(beat.get("placement", &"bottom")),
			beat.get("color", Color.WHITE),
			float(beat.get("hold", 1.0))
		)
	caption.visible = false
	root.visible = false
	active = false
	frame_finished.emit(frame_id)


func hide_immediately() -> void:
	active = false
	_typing = false
	_skip_requested = true
	root.visible = false
	caption.visible = false
	blip.stop()


func _show_caption(speaker: StringName, text: String, placement: StringName, color: Color, hold: float) -> void:
	_place_caption(placement, text)
	caption_text.text = text
	caption_text.visible_characters = 0
	caption_text.add_theme_color_override(&"font_color", color)
	caption.visible = true
	caption.modulate.a = 0.0
	await create_tween().tween_property(caption, "modulate:a", 1.0, _duration(0.14)).finished
	line_started.emit(speaker, text)
	_typing = true
	_skip_requested = false
	if instant_mode:
		caption_text.visible_characters = -1
	else:
		for index in text.length():
			if _skip_requested:
				caption_text.visible_characters = -1
				break
			caption_text.visible_characters = index + 1
			var character := text.substr(index, 1)
			if not character.strip_edges().is_empty() and index % 4 == 0:
				blip.pitch_scale = randf_range(0.98, 1.02)
				blip.play()
			await get_tree().create_timer(_duration(1.0 / characters_per_second)).timeout
	_typing = false
	await get_tree().create_timer(_duration(hold)).timeout
	await create_tween().tween_property(caption, "modulate:a", 0.0, _duration(0.12)).finished
	caption.visible = false


func _place_caption(placement: StringName, text: String) -> void:
	caption.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var viewport_size := get_viewport().get_visible_rect().size
	var side_layout := placement == &"left" or placement == &"right"
	var max_width := minf(500.0 if side_layout else 720.0, viewport_size.x - 64.0)
	var min_width := minf(250.0, max_width)
	var desired_width := clampf(175.0 + sqrt(float(maxi(text.length(), 1))) * 38.0, min_width, max_width)
	var chars_per_line := maxi(18, int((desired_width - 48.0) / 13.0))
	var line_count := _wrapped_line_count(text, chars_per_line)
	var desired_height := clampf(28.0 + float(line_count) * 31.0, 70.0, 184.0)
	var margin := 32.0
	caption_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	match placement:
		&"top":
			caption.position = Vector2((viewport_size.x - desired_width) * 0.5, margin)
		&"left":
			caption.position = Vector2(margin, viewport_size.y - desired_height - 42.0)
		&"right":
			caption.position = Vector2(viewport_size.x - desired_width - margin, viewport_size.y - desired_height - 42.0)
		_:
			caption.position = Vector2((viewport_size.x - desired_width) * 0.5, viewport_size.y - desired_height - 42.0)
			caption_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.size = Vector2(desired_width, desired_height)
	caption.position.x = clampf(caption.position.x, margin, viewport_size.x - desired_width - margin)
	caption.position.y = clampf(caption.position.y, margin, viewport_size.y - desired_height - margin)


func _wrapped_line_count(text: String, max_characters: int) -> int:
	var count := 0
	for paragraph in text.split("\n"):
		var line_length := 0
		for word in paragraph.split(" ", false):
			var word_length := word.length()
			if line_length > 0 and line_length + 1 + word_length > max_characters:
				count += 1
				line_length = word_length
			else:
				line_length += word_length + (1 if line_length > 0 else 0)
		count += 1
	return maxi(count, 1)


func _flash() -> void:
	flash.modulate.a = 0.94
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, _duration(0.24))
	await tween.finished


func _duration(seconds: float) -> float:
	return maxf(seconds * timing_scale, 0.001)
