extends Node

const PROFILE_PATH := "user://day0_profile.cfg"
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_RESOLUTION := Vector2i(1280, 720)
const CHECKPOINT_SCENES := {
	"scene0": "res://scenes/main/main.tscn",
	"scene1": "res://scenes/rooftop/rooftop.tscn",
	"scene2": "res://scenes/gameplay/scoped_target_scene.tscn",
	# Preserve older saves while routing the retired standalone interrogation into the desk UI.
	"interrogation": "res://scenes/gameplay/broadcast_interface.tscn",
	"broadcast": "res://scenes/gameplay/broadcast_interface.tscn",
}

var player_name := "MC"
var checkpoint := ""
var master_volume := 1.0
var sfx_volume := 1.0
var ambience_volume := 1.0
var ui_volume := 1.0
var fullscreen := false
var resolution := DEFAULT_RESOLUTION
var profile_path := PROFILE_PATH
var settings_path := SETTINGS_PATH
var pending_broadcast_package: BroadcastPackage


func set_pending_broadcast(report_id: StringName, sequence: BroadcastSequence) -> void:
	pending_broadcast_package = BroadcastPackage.from_sequence(report_id, sequence)


func clear_pending_broadcast() -> void:
	pending_broadcast_package = null


func _ready() -> void:
	load_profile()
	load_settings()
	apply_settings()


func validate_player_name(raw_name: String) -> bool:
	var candidate := normalize_player_name(raw_name)
	if candidate.length() < 1 or candidate.length() > 10:
		return false
	var allowed := RegEx.new()
	allowed.compile("^[\\p{L} '\\-]+$")
	var letter := RegEx.new()
	letter.compile("\\p{L}")
	return allowed.search(candidate) != null and letter.search(candidate) != null


func normalize_player_name(raw_name: String) -> String:
	var candidate := raw_name.strip_edges()
	var whitespace := RegEx.new()
	whitespace.compile("\\s+")
	return whitespace.sub(candidate, " ", true)


func start_new_game(raw_name: String) -> bool:
	if not validate_player_name(raw_name):
		return false
	player_name = normalize_player_name(raw_name)
	checkpoint = "scene0"
	save_profile()
	return true


func begin_day_zero() -> void:
	player_name = "MC"
	checkpoint = "scene0"
	save_profile()


func set_player_name(raw_name: String) -> bool:
	if not validate_player_name(raw_name):
		return false
	player_name = normalize_player_name(raw_name)
	save_profile()
	return true


func has_continue() -> bool:
	return validate_player_name(player_name) and CHECKPOINT_SCENES.has(checkpoint)


func continue_scene_path() -> String:
	return CHECKPOINT_SCENES.get(checkpoint, "")


func save_checkpoint(value: String) -> void:
	if not CHECKPOINT_SCENES.has(value):
		return
	checkpoint = value
	save_profile()


func save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "player_name", player_name)
	config.set_value("profile", "checkpoint", checkpoint)
	config.save(profile_path)


func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(profile_path) != OK:
		return
	player_name = str(config.get_value("profile", "player_name", "MC"))
	checkpoint = str(config.get_value("profile", "checkpoint", ""))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "ambience", ambience_volume)
	config.set_value("audio", "ui", ui_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "resolution", resolution)
	config.save(settings_path)
	apply_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	master_volume = clampf(float(config.get_value("audio", "master", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	ambience_volume = clampf(float(config.get_value("audio", "ambience", 1.0)), 0.0, 1.0)
	ui_volume = clampf(float(config.get_value("audio", "ui", 1.0)), 0.0, 1.0)
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	resolution = config.get_value("display", "resolution", DEFAULT_RESOLUTION)


func apply_settings() -> void:
	_set_bus_volume(&"Master", master_volume)
	_set_bus_volume(&"SFX", sfx_volume)
	_set_bus_volume(&"Ambience", ambience_volume)
	_set_bus_volume(&"UI", ui_volume)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if not fullscreen:
		DisplayServer.window_set_size(resolution)


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_mute(bus_index, linear <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear, 0.001)))
