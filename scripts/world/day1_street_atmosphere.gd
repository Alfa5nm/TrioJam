class_name Day1StreetAtmosphere
extends Node

@export var camera_capture_path: NodePath
@export var secondary_camera_capture_path: NodePath
@export_range(-60.0, 0.0, 0.5) var wind_volume_db := -27.0
@export_range(-60.0, 0.0, 0.5) var birds_volume_db := -33.0
@export_range(0.0, 24.0, 0.5) var cutscene_duck_db := 12.0

@onready var wind: AudioStreamPlayer = $Wind
@onready var birds: AudioStreamPlayer = $Birds

var is_ducked := false
var _mix_tween: Tween


func _ready() -> void:
	_configure_loop(wind)
	_configure_loop(birds)
	wind.volume_db = wind_volume_db
	birds.volume_db = birds_volume_db
	wind.play()
	birds.play()
	_connect_capture(camera_capture_path)
	_connect_capture(secondary_camera_capture_path)


func _connect_capture(path: NodePath) -> void:
	if path.is_empty():
		return
	var camera_capture := get_node_or_null(path)
	if camera_capture == null:
		return
	if camera_capture.has_signal(&"capture_started"):
		camera_capture.capture_started.connect(duck_for_cutscene)
	if camera_capture.has_signal(&"capture_finished"):
		camera_capture.capture_finished.connect(restore_after_cutscene)


func duck_for_cutscene() -> void:
	is_ducked = true
	_fade_mix(wind_volume_db - cutscene_duck_db, birds_volume_db - cutscene_duck_db, 0.45)


func restore_after_cutscene() -> void:
	is_ducked = false
	_fade_mix(wind_volume_db, birds_volume_db, 0.8)


func _configure_loop(player: AudioStreamPlayer) -> void:
	if player.stream is AudioStreamMP3:
		(player.stream as AudioStreamMP3).loop = true


func _fade_mix(wind_target: float, birds_target: float, duration: float) -> void:
	if _mix_tween != null and _mix_tween.is_running():
		_mix_tween.kill()
	_mix_tween = create_tween().set_parallel(true)
	_mix_tween.tween_property(wind, "volume_db", wind_target, duration)
	_mix_tween.tween_property(birds, "volume_db", birds_target, duration)
