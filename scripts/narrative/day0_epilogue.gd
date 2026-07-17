class_name Day0Epilogue
extends Control

signal epilogue_finished

const CURTAIN_SHEET := preload("res://assets/art/Epilogue/curtain-close-sheet-v1.png")
const CURTAIN_CELL_SIZE := Vector2(543, 724)
const CIVILIAN_LINES := [
	"They murdered him!",
	"You believe everything they show you!",
	"The Opposition started this!",
]
const CIVILIAN_HOLDS := [0.7, 0.7, 1.2]
const BEDROOM_LINES := [
	"I watched as the civilians of the country split itself into conflict from the comfort of my bedroom.",
	"People who had shared the same streets that morning now looked at one another like enemies. All because of one report.",
	"I indulged in my prosaic practice of depravity, but my mind wouldn't waver from the fact that I was the one who caused this.",
	"I moved pictures across a desk. I placed one man where another had stood. I replaced a murderer with a convenient enemy.",
	"My gunshot was the kick to this conflict. This simple motion made the consequences appalling to witness.",
	"However, to see how easy it was made me sick to my stomach. Regardless, he needed to die.",
	"The guilt I felt for the unrest wouldn't even compare to the sense of apathy I felt for killing that person.",
	"...",
]
const FINAL_LINE := "I have to work tomorrow..."

@export var instant_mode := false
@export_range(0.01, 1.0, 0.01) var timing_scale := 1.0

var _civilian_index := 0
var _bedroom_index := -1
var _typing := false
var _visible_count := 0
var _type_accumulator := 0.0
var _closing := false
var _finished := false
var _hold_active := false

@onready var bedroom: Control = %Bedroom
@onready var curtains: AnimatedSprite2D = %Curtains
@onready var speaker_label: Label = %SpeakerLabel
@onready var dialogue_label: Label = %DialogueLabel
@onready var dialogue_panel: PanelContainer = %DialoguePanel
@onready var advance_prompt: Label = %AdvancePrompt
@onready var protest_glow: ColorRect = %ProtestGlow
@onready var fire_glow: Polygon2D = %FireGlow
@onready var gun_flash: Polygon2D = %GunFlash
@onready var curtain_rustle: AudioStreamPlayer = %CurtainRustle
@onready var blip: AudioStreamPlayer = %Blip
@onready var bedroom_fade: ColorRect = %BedroomFade


func _ready() -> void:
	_setup_curtain_frames()
	curtains.animation_finished.connect(_on_curtains_closed)
	bedroom.visible = false
	dialogue_panel.set_anchors_preset(Control.PRESET_CENTER)
	_present_civilian_line()


func _process(delta: float) -> void:
	if not _typing or instant_mode:
		return
	_type_accumulator += delta
	while _type_accumulator >= 0.034 and _typing:
		_type_accumulator -= 0.034
		_visible_count += 1
		dialogue_label.visible_characters = _visible_count
		if _visible_count % 2 == 0 and _visible_count <= dialogue_label.text.length():
			var character := dialogue_label.text.substr(_visible_count - 1, 1)
			if not character.strip_edges().is_empty():
				blip.pitch_scale = randf_range(0.91, 1.06)
				blip.play()
		if _visible_count >= dialogue_label.text.length():
			_finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") or (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	):
		_request_advance()
		get_viewport().set_input_as_handled()


func _request_advance() -> void:
	if _closing or _finished or _hold_active:
		return
	if _typing:
		dialogue_label.visible_characters = -1
		_finish_typing()
		return
	if _bedroom_index < 0:
		if _civilian_index < CIVILIAN_LINES.size() - 1:
			_civilian_index += 1
			_present_civilian_line()
		else:
			_enter_bedroom()
		return
	if _bedroom_index < BEDROOM_LINES.size() - 1:
		_bedroom_index += 1
		_present_bedroom_line()
	else:
		_begin_curtain_close()


func _present_civilian_line() -> void:
	speaker_label.text = "Civilian %d" % (_civilian_index + 1)
	speaker_label.visible = true
	_start_typewriter(CIVILIAN_LINES[_civilian_index])


func _enter_bedroom() -> void:
	_bedroom_index = 0
	bedroom.visible = true
	speaker_label.visible = false
	bedroom_fade.modulate.a = 1.0
	dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dialogue_panel.offset_left = -500.0
	dialogue_panel.offset_top = -180.0
	dialogue_panel.offset_right = 500.0
	dialogue_panel.offset_bottom = -26.0
	var reveal := create_tween()
	reveal.tween_property(bedroom_fade, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_present_bedroom_line()


func _present_bedroom_line() -> void:
	_start_typewriter(BEDROOM_LINES[_bedroom_index])
	if _bedroom_index == 4:
		_pulse_unrest_reflection()


func _start_typewriter(text: String) -> void:
	dialogue_label.text = text
	_visible_count = 0
	_type_accumulator = 0.0
	dialogue_label.visible_characters = 0
	advance_prompt.visible = false
	_typing = true
	if instant_mode:
		dialogue_label.visible_characters = -1
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	dialogue_label.visible_characters = -1
	if _bedroom_index < 0:
		_begin_civilian_hold()
	else:
		advance_prompt.visible = true


func _begin_civilian_hold() -> void:
	_hold_active = true
	advance_prompt.visible = false
	await get_tree().create_timer(_duration(CIVILIAN_HOLDS[_civilian_index])).timeout
	if not is_inside_tree():
		return
	_hold_active = false
	advance_prompt.visible = true


func _pulse_unrest_reflection() -> void:
	protest_glow.modulate.a = 0.18
	fire_glow.modulate.a = 0.16
	gun_flash.modulate.a = 0.52
	var glow := create_tween().set_parallel(true)
	glow.tween_property(protest_glow, "modulate:a", 0.12, 2.15).set_trans(Tween.TRANS_SINE)
	glow.tween_property(fire_glow, "modulate:a", 0.13, 2.15).set_trans(Tween.TRANS_SINE)
	var flash := create_tween()
	flash.tween_property(gun_flash, "modulate:a", 0.0, 0.36).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _begin_curtain_close() -> void:
	_closing = true
	dialogue_panel.visible = false
	curtain_rustle.play()
	curtains.play(&"close")


func _on_curtains_closed() -> void:
	if not _closing:
		return
	_closing = false
	_finished = true
	dialogue_panel.visible = true
	dialogue_label.text = FINAL_LINE
	dialogue_label.visible_characters = -1
	advance_prompt.visible = false
	epilogue_finished.emit()


func _setup_curtain_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(&"close")
	frames.set_animation_loop(&"close", false)
	frames.set_animation_speed(&"close", 2.8)
	for column in 4:
		var frame := AtlasTexture.new()
		frame.atlas = CURTAIN_SHEET
		frame.region = Rect2(Vector2(column * CURTAIN_CELL_SIZE.x, 0), CURTAIN_CELL_SIZE)
		frames.add_frame(&"close", frame)
	curtains.sprite_frames = frames
	curtains.animation = &"close"
	curtains.frame = 0


func _duration(seconds: float) -> float:
	return maxf(seconds * timing_scale, 0.001)
