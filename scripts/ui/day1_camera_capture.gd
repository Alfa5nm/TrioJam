class_name Day1CameraCapture
extends CanvasLayer

signal capture_started
signal frame_captured(index: int)
signal capture_finished
signal line_started(speaker: String, text: String, phase: StringName)
signal aftermath_requested
signal escape_requested

@export_range(0.01, 1.0, 0.01) var timing_scale := 1.0
@export var instant_mode := false
@export_range(8.0, 100.0, 1.0) var characters_per_second := 24.0
@export_range(0.0, 0.5, 0.01) var punctuation_pause := 0.13

@onready var overlay: Control = $Overlay
@onready var frame_image: TextureRect = $Overlay/FrameImage
@onready var blackout: ColorRect = $Overlay/Blackout
@onready var camera_chrome: Control = $Overlay/CameraChrome
@onready var frame_counter: Label = $Overlay/CameraChrome/FrameCounter
@onready var caption_panel: PanelContainer = $Overlay/CaptionPanel
@onready var caption: Label = $Overlay/CaptionPanel/Margin/Caption
@onready var flash: ColorRect = $Overlay/Flash
@onready var previews: Array[TextureRect] = [
	$Overlay/HiddenPreviews/Frame1,
	$Overlay/HiddenPreviews/Frame2,
	$Overlay/HiddenPreviews/Frame3,
]
@onready var blip: AudioStreamPlayer = $Blip
@onready var camera_click: AudioStreamPlayer = $CameraClick
@onready var hit: AudioStreamPlayer = $Hit
@onready var shove: AudioStreamPlayer = $Shove
@onready var scuffle: AudioStreamPlayer = $Scuffle
@onready var gunshot: AudioStreamPlayer = $Gunshot
@onready var running: AudioStreamPlayer = $Running
@onready var breathing: AudioStreamPlayer = $Breathing
@onready var crowd: AudioStreamPlayer = $Crowd
@onready var tense: AudioStreamPlayer = $TenseAmbience

var active := false
var captured_frames := 0
var _base_caption_style: StyleBoxFlat

const SOLDIER_TEXT_COLOR := Color(1.0, 0.28, 0.25, 1.0)
const SOLDIER_BORDER_COLOR := Color(0.96, 0.16, 0.18, 0.98)
const CIVILIAN_TEXT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const CIVILIAN_BORDER_COLOR := Color(0.84, 0.93, 1.0, 0.98)
const MC_TEXT_COLOR := Color(0.78, 0.91, 1.0, 1.0)
const BYSTANDER_TEXT_COLOR := Color(1.0, 0.9, 0.72, 1.0)
const REPRESENTATIVE_TEXT_COLOR := Color(0.42, 0.94, 1.0, 1.0)
const OPPOSITION_TEXT_COLOR := Color(1.0, 0.78, 0.32, 1.0)


func _ready() -> void:
	overlay.visible = false
	flash.modulate.a = 0.0
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var initial_style := caption_panel.get_theme_stylebox(&"panel")
	if initial_style is StyleBoxFlat:
		_base_caption_style = (initial_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	tense.finished.connect(_restart_tense_ambience)


func begin_capture() -> void:
	if active:
		return
	active = true
	captured_frames = 0
	for preview in previews:
		preview.texture = null
	overlay.visible = true
	camera_chrome.visible = true
	caption_panel.visible = false
	frame_image.visible = true
	blackout.visible = false
	tense.play()
	capture_started.emit()

	await _show_frame(preload("res://assets/art/Day1 Scene 1/camera-cutscene/frame-1-soldier-hit.png"), 1)
	hit.play()
	scuffle.play()
	await _line("Civilian", "What the hell–?! Why are you hitting me?!", &"frame_1", 0.5)
	await _line("Soldier", "You are under arrest for unlawful assembly, public disruption and possession of prohibited political material.", &"frame_1", 0.65)
	await _line("Civilian", "What…?! No no no! You can’t do that! I’m alone! There is no assembly!", &"frame_1", 0.6)
	await _line("Soldier", "Your belongings will be confiscated as evidence.", &"frame_1", 0.55)
	await _line("Civilian", "GIVE. THAT BACK!!", &"frame_1", 0.55)

	await _show_frame(preload("res://assets/art/Day1 Scene 1/camera-cutscene/frame-2-civilian-shove.png"), 2)
	shove.play()
	await _line("Civilian", "Don’t hit me! I didn’t do anything wrong!", &"frame_2", 0.55)
	await _line("Soldier", "Oh don’t you dare hit me with your filthy hands! You attacked a member of the national security force!", &"frame_2", 0.65)
	await _line("Civilian", "I was defending myself!", &"frame_2", 0.55)

	await _show_gunshot_frame()
	await _line("Civilian", "AH–!", &"frame_3", 0.42)
	await _black_mc_line("Oh my fucking god—", 0.7)

	aftermath_requested.emit()
	frame_image.visible = false
	blackout.visible = false
	camera_chrome.visible = false
	crowd.play()
	await get_tree().process_frame
	await _line("Bystander", "He killed him!", &"aftermath", 0.5)
	await _line("Bystander", "Someone call for help!", &"aftermath", 0.5)
	await _line("Bystander", "Murderer!", &"aftermath", 0.55)

	breathing.play()
	await _black_mc_line("(Shit shit shit… This isn’t good.)", 0.65)
	await _black_mc_line("(But if I help them, I’m doomed, so is she. I… can’t risk my life here.)", 0.75)
	await _black_mc_line("(I need to get the fuck out of here.)", 0.7)
	running.play()
	escape_requested.emit()
	await _wait(1.0)
	await _fade_out_black()

	active = false
	overlay.visible = false
	caption_panel.visible = false
	_stop_audio()
	capture_finished.emit()


func capture_frame() -> void:
	# Retained as a harmless compatibility entry point. The authored sequence is
	# automatic now and no longer captures the gameplay viewport.
	return


func _show_frame(texture: Texture2D, index: int) -> void:
	blackout.visible = false
	frame_image.visible = true
	frame_image.texture = texture
	camera_chrome.visible = true
	frame_counter.text = "FRAME %02d / 03" % index
	captured_frames = index
	previews[index - 1].texture = texture
	frame_captured.emit(index)
	camera_click.play()
	flash.color = Color(0.82, 0.94, 1.0, 1.0)
	flash.modulate.a = 0.75
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, _duration(0.16))
	await _wait(0.28)


func _show_gunshot_frame() -> void:
	frame_image.visible = false
	blackout.visible = true
	blackout.color = Color.BLACK
	camera_chrome.visible = true
	frame_counter.text = "FRAME 03 / 03"
	captured_frames = 3
	var black_preview := Image.create(16, 9, false, Image.FORMAT_RGBA8)
	black_preview.fill(Color.BLACK)
	previews[2].texture = ImageTexture.create_from_image(black_preview)
	frame_captured.emit(3)
	scuffle.play()
	await _wait(0.36)
	gunshot.play()
	flash.color = Color(1.0, 0.14, 0.12, 1.0)
	flash.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, _duration(0.32))
	await _wait(0.22)


func _black_mc_line(text: String, hold: float) -> void:
	frame_image.visible = false
	blackout.visible = true
	blackout.color = Color.BLACK
	camera_chrome.visible = false
	await _line("MC", text, &"mc_black", hold)


func _line(
		speaker: String,
		text: String,
		phase: StringName,
		hold: float,
		caption_slot: StringName = &""
	) -> void:
	_apply_caption_style(speaker, phase)
	if not caption_slot.is_empty():
		_apply_caption_slot(caption_slot)
	line_started.emit(speaker, text, phase)
	caption_panel.visible = true
	caption_panel.modulate.a = 1.0 if instant_mode else 0.0
	caption.text = text
	caption.visible_characters = 0
	if instant_mode:
		caption.visible_characters = -1
		await get_tree().process_frame
	else:
		var reveal := create_tween()
		reveal.tween_property(caption_panel, "modulate:a", 1.0, _duration(0.14))
		await reveal.finished
		var character_delay := 1.0 / characters_per_second
		for index in text.length():
			caption.visible_characters = index + 1
			var character := text.substr(index, 1)
			if not character.strip_edges().is_empty() and character not in ".,…!?—–-":
				blip.pitch_scale = randf_range(0.94, 1.04)
				blip.play()
			var delay := character_delay
			if character in ".,â€¦!?":
				delay += punctuation_pause
			await get_tree().create_timer(_duration(delay)).timeout
	var readable_hold := maxf(hold, clampf(float(text.length()) * 0.017, 0.9, 1.9))
	await _wait(readable_hold)
	if not instant_mode:
		var dismiss := create_tween()
		dismiss.tween_property(caption_panel, "modulate:a", 0.0, _duration(0.14))
		await dismiss.finished
	caption_panel.visible = false


func _apply_caption_style(speaker: String, phase: StringName) -> void:
	var text_color := CIVILIAN_TEXT_COLOR
	var border_color := CIVILIAN_BORDER_COLOR
	caption_panel.anchor_top = 1.0
	caption_panel.anchor_bottom = 1.0
	caption_panel.offset_top = -190.0
	caption_panel.offset_bottom = -28.0
	match speaker:
		"Soldier":
			text_color = SOLDIER_TEXT_COLOR
			border_color = SOLDIER_BORDER_COLOR
			caption_panel.anchor_left = 0.0
			caption_panel.anchor_right = 0.52
			caption_panel.offset_left = 48.0
			caption_panel.offset_right = -18.0
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		"Civilian":
			text_color = CIVILIAN_TEXT_COLOR
			border_color = CIVILIAN_BORDER_COLOR
			caption_panel.anchor_left = 0.48
			caption_panel.anchor_right = 1.0
			caption_panel.offset_left = 18.0
			caption_panel.offset_right = -48.0
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		"MC":
			text_color = MC_TEXT_COLOR
			border_color = Color(0.28, 0.68, 1.0, 0.98)
			_center_caption_panel()
		"Bystander":
			text_color = BYSTANDER_TEXT_COLOR
			border_color = Color(0.95, 0.68, 0.3, 0.98)
			_center_caption_panel()
		"REP", "Company Representative":
			text_color = REPRESENTATIVE_TEXT_COLOR
			border_color = Color(0.1, 0.78, 0.94, 0.98)
			_center_caption_panel()
		"Farmers", "Opposition Volunteer", "Opposition":
			text_color = OPPOSITION_TEXT_COLOR
			border_color = Color(0.94, 0.52, 0.12, 0.98)
			_center_caption_panel()
		"Crowd", "Civilian Customer":
			text_color = CIVILIAN_TEXT_COLOR
			border_color = CIVILIAN_BORDER_COLOR
			_center_caption_panel()
		_:
			_center_caption_panel()
	if phase == &"mc_black":
		_center_caption_panel()
	caption.add_theme_color_override(&"font_color", text_color)
	if _base_caption_style != null:
		var speaker_style := _base_caption_style.duplicate() as StyleBoxFlat
		speaker_style.border_color = border_color
		speaker_style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.2)
		caption_panel.add_theme_stylebox_override(&"panel", speaker_style)


func _center_caption_panel() -> void:
	caption_panel.anchor_left = 0.12
	caption_panel.anchor_right = 0.88
	caption_panel.offset_left = 0.0
	caption_panel.offset_right = 0.0
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _apply_caption_slot(slot: StringName) -> void:
	match slot:
		&"left":
			caption_panel.anchor_left = 0.0
			caption_panel.anchor_right = 0.52
			caption_panel.offset_left = 48.0
			caption_panel.offset_right = -18.0
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		&"right":
			caption_panel.anchor_left = 0.48
			caption_panel.anchor_right = 1.0
			caption_panel.offset_left = 18.0
			caption_panel.offset_right = -48.0
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_:
			_center_caption_panel()


func _fade_out_black() -> void:
	blackout.visible = true
	blackout.color = Color.BLACK
	blackout.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(blackout, "modulate:a", 0.0, _duration(0.7))
	await tween.finished
	blackout.modulate.a = 1.0


func _restart_tense_ambience() -> void:
	if active:
		tense.play()


func _stop_audio() -> void:
	for player in [blip, camera_click, hit, shove, scuffle, gunshot, running, breathing, crowd, tense]:
		player.stop()


func _wait(seconds: float) -> void:
	if instant_mode:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(_duration(seconds)).timeout


func _duration(seconds: float) -> float:
	return maxf(seconds * timing_scale, 0.001)
