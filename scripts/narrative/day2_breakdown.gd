class_name Day2Breakdown
extends Control

signal ending_started
signal ending_finished

@export var instant_mode := false
@export_range(0.1, 2.0, 0.05) var timing_scale := 1.0

var _skip_requested := false
var _typing := false

@onready var cg: TextureRect = $CG
@onready var darkness: ColorRect = $Darkness
@onready var caption: Label = $CaptionPanel/Margin/Caption
@onready var caption_panel: PanelContainer = $CaptionPanel
@onready var particles: GPUParticles2D = $BreakdownParticles
@onready var ambience: AudioStreamPlayer = $Ambience
@onready var breathing: AudioStreamPlayer = $Breathing
@onready var blip: AudioStreamPlayer = $Blip


func _ready() -> void:
	caption_panel.visible = false
	cg.modulate.a = 0.0
	darkness.modulate.a = 1.0
	_set_loop(ambience, true)
	_set_loop(breathing, true)
	ambience.play()
	ending_started.emit()
	call_deferred(&"_run_sequence")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") or (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	):
		if _typing:
			_skip_requested = true
		get_viewport().set_input_as_handled()


func _run_sequence() -> void:
	await _line("I immediately went home after what happened.", 0.9)
	await _line("…", 0.65)
	await _show_breakdown()
	await _line("I couldn't be the one to tell you what was off, I missed a whole week… maybe a few weeks of work.", 0.95)
	await _line("I fell down a rabbit hole, a domino effect that started with a single shot.", 0.9)
	await _line("I know, they know, we know…. that something isn't right", 0.85)
	await _line("After this, my life eclipsed into fear, day and night", 0.85)
	await _line("…", 0.65)
	await _hide_breakdown()
	await _line("After a few days, I received a message from higher-ups to meet at abandoned building again.", 0.95)
	await _line("….", 0.7)
	await _line("I need to go.", 0.9)
	ending_finished.emit()
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.complete_day2()
		session.begin_day3()
	var transition := get_node_or_null("/root/SceneTransition")
	if transition != null and not transition.busy:
		transition.transition_to("res://scenes/Day 3/day3_stairwell.tscn", false)
	else:
		get_tree().change_scene_to_file("res://scenes/Day 3/day3_stairwell.tscn")


func _show_breakdown() -> void:
	breathing.play()
	particles.emitting = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(cg, "modulate:a", 1.0, _duration(0.65))
	tween.tween_property(darkness, "modulate:a", 0.08, _duration(0.65))
	tween.tween_property(cg, "scale", Vector2(1.055, 1.055), _duration(9.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(_duration(0.7)).timeout


func _hide_breakdown() -> void:
	particles.emitting = false
	breathing.stop()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(cg, "modulate:a", 0.0, _duration(0.55))
	tween.tween_property(darkness, "modulate:a", 1.0, _duration(0.55))
	await tween.finished


func _line(text: String, hold: float) -> void:
	caption_panel.visible = true
	caption.text = text
	caption.visible_characters = 0
	_skip_requested = false
	_typing = true
	if instant_mode:
		caption.visible_characters = -1
	else:
		for index in text.length():
			if _skip_requested:
				caption.visible_characters = -1
				break
			caption.visible_characters = index + 1
			if index % 3 == 0 and not text.substr(index, 1).strip_edges().is_empty():
				blip.pitch_scale = randf_range(0.86, 0.96)
				blip.play()
			await get_tree().create_timer(_duration(0.047)).timeout
	_typing = false
	await get_tree().create_timer(_duration(hold)).timeout
	caption_panel.visible = false


func _set_loop(player: AudioStreamPlayer, enabled: bool) -> void:
	if player.stream is AudioStreamWAV:
		(player.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED
	elif player.stream is AudioStreamMP3:
		(player.stream as AudioStreamMP3).loop = enabled
	elif player.stream is AudioStreamOggVorbis:
		(player.stream as AudioStreamOggVorbis).loop = enabled


func _duration(seconds: float) -> float:
	return maxf(seconds * timing_scale, 0.001)
