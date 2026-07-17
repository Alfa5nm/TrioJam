extends CanvasLayer

signal transition_finished(scene_path: String)

const OPEN_STREAM := preload("res://assets/audio/transitions/metal-door-opening.ogg")
const CLOSE_STREAM := preload("res://assets/audio/transitions/metal-door-closing.ogg")

var timing_scale := 1.0
var busy := false
var fade: ColorRect
var door_open: AudioStreamPlayer
var door_close: AudioStreamPlayer


func _ready() -> void:
	layer = 120
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.003, 0.005, 0.009, 1)
	fade.modulate.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	door_open = AudioStreamPlayer.new()
	door_open.stream = OPEN_STREAM
	door_open.bus = &"SFX"
	add_child(door_open)
	door_close = AudioStreamPlayer.new()
	door_close.stream = CLOSE_STREAM
	door_close.bus = &"SFX"
	add_child(door_close)


func transition_to(scene_path: String, use_door := true) -> void:
	if busy:
		return
	busy = true
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if use_door:
		door_open.play()
		await door_open.finished
	var cover := create_tween()
	cover.tween_property(fade, "modulate:a", 1.0, _duration(0.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await cover.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	var reveal := create_tween()
	reveal.tween_property(fade, "modulate:a", 0.0, _duration(0.65)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await reveal.finished
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if use_door:
		door_close.play()
		await door_close.finished
	busy = false
	transition_finished.emit(scene_path)


func _duration(seconds: float) -> float:
	return maxf(seconds * timing_scale, 0.001)
