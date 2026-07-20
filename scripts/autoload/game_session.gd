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
	"day1_scene1": "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn",
	"day1_ending": "res://scenes/Day 1/Side Scroll Section/Day 1 ending.tscn",
	"day2": "res://scenes/Day 2/day2_peace_rally.tscn",
	"day2_rally": "res://scenes/Day 2/day2_peace_rally.tscn",
	"day2_breakdown": "res://scenes/Day 2/day2_breakdown.tscn",
	"day3_stairwell": "res://scenes/Day 3/day3_stairwell.tscn",
	"day3_stairwell_return": "res://scenes/Day 3/day3_stairwell_return.tscn",
	"day3_briefing": "res://scenes/Day 3/day3_briefing_room.tscn",
	"day3_rooftop": "res://scenes/Day 3/day3_rooftop.tscn",
	"day3_scope": "res://scenes/Day 3/day3_scope_scene.tscn",
	"day3_finale": "res://scenes/Day 3/day3_finale.tscn",
	"day3_credits": "res://scenes/Day 3/day3_finale.tscn",
}

const DAY0_REPORT_ROOFTOP := &"day0_rooftop_killing"
const DAY1_REPORT_CHECKPOINT := &"day1_checkpoint_killing"
const DAY1_REPORT_SEEDLESS := &"day1_seedless_fruit"
const DAY2_REPORT_BOMBING := &"day2_bombing"
const ROUTE_TRUTHFUL := &"truthful"
const ROUTE_PROPAGANDA := &"propaganda"
const DAY3_NOT_SHOOT := &"not_shoot"
const DAY3_SHOOT := &"shoot"

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
var pending_broadcast_packages: Dictionary = {}
var broadcast_context: StringName = &"day0"
var day0_rooftop_route: StringName = &""
var day1_checkpoint_route: StringName = &""
var day1_seedless_route: StringName = &""
var day2_bombing_route: StringName = &""
var day3_briefing_complete := false
var day3_resolution: StringName = &""
var last_completed_day3_route: StringName = &""
var day3_debug_route_override: StringName = &""
var current_objective := ""
var current_objective_scene := ""
var _day3_route_music_player: AudioStreamPlayer
var _day3_route_music_route: StringName = &""


func set_pending_broadcast(report_id: StringName, sequence: BroadcastSequence) -> void:
	set_pending_broadcast_package(BroadcastPackage.from_sequence(report_id, sequence))


func set_pending_broadcast_package(package: BroadcastPackage) -> void:
	if package == null or package.report_id == &"":
		return
	pending_broadcast_package = package
	pending_broadcast_packages[package.report_id] = package


func get_pending_broadcast_package(report_id: StringName) -> BroadcastPackage:
	var package = pending_broadcast_packages.get(report_id)
	if package is BroadcastPackage:
		return package
	if pending_broadcast_package != null and pending_broadcast_package.report_id == report_id:
		return pending_broadcast_package
	return null


func clear_pending_broadcast() -> void:
	pending_broadcast_package = null
	pending_broadcast_packages.clear()


func begin_day1_broadcast() -> void:
	clear_pending_broadcast()
	broadcast_context = &"day1"
	day1_checkpoint_route = &""
	day1_seedless_route = &""
	checkpoint = "broadcast"
	save_profile()


func set_day0_report_route(route: StringName) -> void:
	if route not in [ROUTE_TRUTHFUL, ROUTE_PROPAGANDA]:
		return
	day0_rooftop_route = route
	save_profile()


func begin_day1_scene1() -> void:
	broadcast_context = &"day1_story"
	day1_checkpoint_route = &""
	day1_seedless_route = &""
	checkpoint = "day1_scene1"
	save_profile()


func set_day1_report_route(report_id: StringName, route: StringName) -> void:
	if route not in [ROUTE_TRUTHFUL, ROUTE_PROPAGANDA]:
		return
	match report_id:
		DAY1_REPORT_CHECKPOINT:
			day1_checkpoint_route = route
		DAY1_REPORT_SEEDLESS:
			day1_seedless_route = route
		_:
			return
	save_profile()


func get_day1_report_route(report_id: StringName) -> StringName:
	match report_id:
		DAY1_REPORT_CHECKPOINT:
			return day1_checkpoint_route
		DAY1_REPORT_SEEDLESS:
			return day1_seedless_route
		_:
			return &""


func complete_day1() -> void:
	broadcast_context = &"day1_complete"
	checkpoint = "day2"
	save_profile()


func begin_day2() -> void:
	broadcast_context = &"day2_story"
	day2_bombing_route = &""
	checkpoint = "day2_rally"
	save_profile()


func begin_day2_broadcast() -> void:
	clear_pending_broadcast()
	broadcast_context = &"day2"
	checkpoint = "broadcast"
	save_profile()


func set_day2_report_route(route: StringName) -> void:
	if route not in [ROUTE_TRUTHFUL, ROUTE_PROPAGANDA]:
		return
	day2_bombing_route = route
	save_profile()


func get_day2_report_route() -> StringName:
	return day2_bombing_route


func complete_day2() -> void:
	broadcast_context = &"day2_complete"
	checkpoint = "day3_stairwell"
	save_profile()


func begin_day3() -> void:
	broadcast_context = &"day3"
	day3_briefing_complete = false
	day3_resolution = &""
	day3_debug_route_override = &""
	checkpoint = "day3_stairwell"
	save_profile()


func mark_day3_briefing_complete() -> void:
	day3_briefing_complete = true
	checkpoint = "day3_stairwell_return"
	save_profile()


func has_complete_day3_report_history() -> bool:
	return day1_checkpoint_route in [ROUTE_TRUTHFUL, ROUTE_PROPAGANDA] \
		and day1_seedless_route in [ROUTE_TRUTHFUL, ROUTE_PROPAGANDA] \
		and day2_bombing_route in [ROUTE_TRUTHFUL, ROUTE_PROPAGANDA]


func set_day3_debug_route_override(route: StringName) -> void:
	if route in [DAY3_NOT_SHOOT, DAY3_SHOOT]:
		day3_debug_route_override = route


func resolve_day3_route() -> StringName:
	if day3_debug_route_override in [DAY3_NOT_SHOOT, DAY3_SHOOT]:
		return day3_debug_route_override
	if not has_complete_day3_report_history():
		return &""
	var truthful_reports := 0
	for report_route in [day1_checkpoint_route, day1_seedless_route, day2_bombing_route]:
		if report_route == ROUTE_TRUTHFUL:
			truthful_reports += 1
	# Day 0 does not influence the finale. A two-out-of-three truthful majority
	# across the two Day 1 reports and the Day 2 bombing report refuses the order.
	return DAY3_NOT_SHOOT if truthful_reports >= 2 else DAY3_SHOOT


func set_day3_resolution(route: StringName) -> void:
	if route not in [DAY3_NOT_SHOOT, DAY3_SHOOT]:
		return
	day3_resolution = route
	checkpoint = "day3_finale"
	save_profile()


func complete_day3() -> void:
	if day3_resolution in [DAY3_NOT_SHOOT, DAY3_SHOOT]:
		last_completed_day3_route = day3_resolution
	broadcast_context = &"day3_complete"
	checkpoint = ""
	save_profile()


func has_completed_day3_route(route: StringName) -> bool:
	return last_completed_day3_route == route


func start_day3_route_music(route: StringName, fade_seconds := 3.5) -> AudioStreamPlayer:
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		_day3_route_music_route = route
		var cue := &"day3_not_shoot" if route == DAY3_NOT_SHOOT else &"day3_shoot"
		return music_director.play_cue(cue, fade_seconds)
	_ensure_day3_route_music_player()
	if _day3_route_music_player.playing and _day3_route_music_route == route:
		return _day3_route_music_player
	_day3_route_music_route = route
	_day3_route_music_player.stop()
	var target_volume := -10.5
	if route == DAY3_NOT_SHOOT:
		_day3_route_music_player.stream = load("res://assets/audio/day3/music/credits-song-for-my-death.mp3")
	else:
		_day3_route_music_player.stream = load("res://assets/audio/day3/music/credits-song-final-boss.mp3")
		target_volume = -16.0
	if _day3_route_music_player.stream is AudioStreamMP3:
		(_day3_route_music_player.stream as AudioStreamMP3).loop = true
	_day3_route_music_player.volume_db = -36.0 if fade_seconds > 0.0 else target_volume
	_day3_route_music_player.play()
	if fade_seconds > 0.0:
		create_tween().tween_property(_day3_route_music_player, "volume_db", target_volume, fade_seconds)
	return _day3_route_music_player


func stop_day3_route_music(fade_seconds := 0.0) -> void:
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		music_director.stop_cue(fade_seconds)
		_day3_route_music_route = &""
		return
	if not is_instance_valid(_day3_route_music_player) or not _day3_route_music_player.playing:
		return
	if fade_seconds <= 0.0:
		_day3_route_music_player.stop()
		_day3_route_music_route = &""
		return
	var fade_music := create_tween().tween_property(_day3_route_music_player, "volume_db", -40.0, fade_seconds)
	fade_music.finished.connect(func():
		if is_instance_valid(_day3_route_music_player):
			_day3_route_music_player.stop()
		_day3_route_music_route = &""
	)


func get_day3_route_music_player() -> AudioStreamPlayer:
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		return music_director.active_player()
	_ensure_day3_route_music_player()
	return _day3_route_music_player


func _ensure_day3_route_music_player() -> void:
	if is_instance_valid(_day3_route_music_player):
		return
	_day3_route_music_player = AudioStreamPlayer.new()
	_day3_route_music_player.name = "Day3RouteMusic"
	_day3_route_music_player.bus = &"Ambience"
	add_child(_day3_route_music_player)


func _effective_day0_route() -> StringName:
	if day0_rooftop_route in [ROUTE_TRUTHFUL, ROUTE_PROPAGANDA]:
		return day0_rooftop_route
	# Older saves could only leave Day 0 after airing the propaganda report.
	if day1_checkpoint_route in [ROUTE_TRUTHFUL, ROUTE_PROPAGANDA] \
		and day1_seedless_route in [ROUTE_TRUTHFUL, ROUTE_PROPAGANDA]:
		return ROUTE_PROPAGANDA
	return &""


func _ready() -> void:
	load_profile()
	load_settings()
	apply_settings()


func set_current_objective(objective: String) -> void:
	current_objective = objective.strip_edges()
	var scene := get_tree().current_scene
	current_objective_scene = scene.scene_file_path if scene != null else ""


func clear_current_objective() -> void:
	current_objective = ""
	current_objective_scene = ""


func get_current_objective(scene_path := "") -> String:
	var active_path: String = scene_path
	if active_path.is_empty() and get_tree().current_scene != null:
		active_path = get_tree().current_scene.scene_file_path
	if not current_objective.is_empty() and current_objective_scene == active_path:
		return current_objective
	return _default_objective_for_scene(active_path)


func _default_objective_for_scene(scene_path: String) -> String:
	match scene_path:
		"res://scenes/main/main.tscn":
			return "Find a way into the broadcast building."
		"res://scenes/rooftop/rooftop.tscn":
			return "Reach the rooftop and find a clear view."
		"res://scenes/gameplay/scoped_target_scene.tscn":
			return "Document the checkpoint incident."
		"res://scenes/gameplay/broadcast_interface.tscn":
			return "Assemble and submit today's report."
		"res://scenes/gameplay/news_broadcast.tscn":
			return "Watch the report air."
		"res://scenes/narrative/day0_epilogue.tscn":
			return "Leave the building and continue to Day 1."
		"res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn":
			return "Reach the grain depot and document what happens."
		"res://scenes/Day 1/Side Scroll Section/Day 1 ending.tscn":
			return "Return home through the night streets."
		"res://scenes/Day 2/day2_peace_rally.tscn":
			return "Investigate the rally and find a safe way through."
		"res://scenes/Day 2/day2_breakdown.tscn":
			return "Record the consequences of the rally bombing."
		"res://scenes/Day 3/day3_stairwell.tscn":
			return "Climb to the guarded briefing room."
		"res://scenes/Day 3/day3_stairwell_return.tscn":
			return "Continue upstairs to the rooftop."
		"res://scenes/Day 3/day3_briefing_room.tscn":
			return "Approach the table and hear the assignment."
		"res://scenes/Day 3/day3_rooftop.tscn":
			return "Reach the firing position."
		"res://scenes/Day 3/day3_scope_scene.tscn":
			return "Follow the order—or refuse."
		"res://scenes/Day 3/day3_finale.tscn":
			return "Face the consequences of your reports."
		_:
			return "Continue forward."


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
	broadcast_context = &"day0"
	day0_rooftop_route = &""
	day1_checkpoint_route = &""
	day1_seedless_route = &""
	day2_bombing_route = &""
	day3_briefing_complete = false
	day3_resolution = &""
	day3_debug_route_override = &""
	clear_pending_broadcast()
	save_profile()
	return true


func begin_day_zero() -> void:
	player_name = "MC"
	checkpoint = "scene0"
	broadcast_context = &"day0"
	day0_rooftop_route = &""
	day1_checkpoint_route = &""
	day1_seedless_route = &""
	day2_bombing_route = &""
	day3_briefing_complete = false
	day3_resolution = &""
	day3_debug_route_override = &""
	clear_pending_broadcast()
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
	config.set_value("story", "broadcast_context", String(broadcast_context))
	config.set_value("story", "day0_rooftop_route", String(day0_rooftop_route))
	config.set_value("story", "day1_checkpoint_route", String(day1_checkpoint_route))
	config.set_value("story", "day1_seedless_route", String(day1_seedless_route))
	config.set_value("story", "day2_bombing_route", String(day2_bombing_route))
	config.set_value("story", "day3_briefing_complete", day3_briefing_complete)
	config.set_value("story", "day3_resolution", String(day3_resolution))
	config.set_value("story", "last_completed_day3_route", String(last_completed_day3_route))
	config.save(profile_path)


func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(profile_path) != OK:
		return
	player_name = str(config.get_value("profile", "player_name", "MC"))
	checkpoint = str(config.get_value("profile", "checkpoint", ""))
	broadcast_context = StringName(config.get_value("story", "broadcast_context", "day0"))
	day0_rooftop_route = StringName(config.get_value("story", "day0_rooftop_route", ""))
	day1_checkpoint_route = StringName(config.get_value("story", "day1_checkpoint_route", ""))
	day1_seedless_route = StringName(config.get_value("story", "day1_seedless_route", ""))
	day2_bombing_route = StringName(config.get_value("story", "day2_bombing_route", ""))
	day3_briefing_complete = bool(config.get_value("story", "day3_briefing_complete", false))
	day3_resolution = StringName(config.get_value("story", "day3_resolution", ""))
	last_completed_day3_route = StringName(config.get_value("story", "last_completed_day3_route", ""))
	# Migrate completed saves written before the title-screen ending variant was added.
	if last_completed_day3_route not in [DAY3_NOT_SHOOT, DAY3_SHOOT] \
			and broadcast_context == &"day3_complete" \
			and day3_resolution in [DAY3_NOT_SHOOT, DAY3_SHOOT]:
		last_completed_day3_route = day3_resolution
	day3_debug_route_override = &""


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
