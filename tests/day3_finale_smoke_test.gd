extends SceneTree

var failures := 0
var session: Node
var original_profile_path := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("DAY3_FINALE_TEST_START")
	session = root.get_node("GameSession")
	original_profile_path = session.profile_path
	session.profile_path = "user://day3_finale_smoke_test.cfg"
	_check_route_matrix()
	_check_debug_fallback()
	await _check_scene_contracts()
	await _check_both_timelines_complete()
	_check_licensed_music()
	session.profile_path = original_profile_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://day3_finale_smoke_test.cfg"))
	if failures == 0:
		print("DAY3_FINALE_TEST_PASS")
	quit(failures)


func _check_route_matrix() -> void:
	session.day0_rooftop_route = &"propaganda"
	var expected := {
		"truthful/truthful": &"not_shoot",
		"truthful/propaganda": &"shoot",
		"propaganda/truthful": &"shoot",
		"propaganda/propaganda": &"shoot",
	}
	for report_one in [&"truthful", &"propaganda"]:
		for report_two in [&"truthful", &"propaganda"]:
			session.day1_checkpoint_route = report_one
			session.day1_seedless_route = report_two
			var key := "%s/%s" % [report_one, report_two]
			_check(session.resolve_day3_route() == expected[key], "%s resolves to %s" % [key, expected[key]])
	_check(session.has_complete_day3_report_history(), "three accepted report results form complete history")
	_check(session.CHECKPOINT_SCENES.has("day3_credits"), "credits have a resumable Day 3 checkpoint")


func _check_debug_fallback() -> void:
	session.day0_rooftop_route = &""
	session.day1_checkpoint_route = &""
	session.day1_seedless_route = &""
	session.day3_debug_route_override = &""
	_check(session.resolve_day3_route() == &"", "incomplete direct launch requests the debug selector")
	session.set_day3_debug_route_override(&"shoot")
	_check(session.resolve_day3_route() == &"shoot", "debug selector can preview SHOOT")
	session.save_profile()
	var cfg := ConfigFile.new()
	cfg.load(session.profile_path)
	_check(not cfg.has_section_key("story", "day3_debug_route_override"), "debug route is deliberately non-persistent")


func _check_scene_contracts() -> void:
	for scene_path in [
		"res://scenes/Day 3/day3_stairwell.tscn",
		"res://scenes/Day 3/day3_stairwell_return.tscn",
		"res://scenes/Day 3/day3_briefing_room.tscn",
		"res://scenes/Day 3/day3_rooftop.tscn",
		"res://scenes/Day 3/day3_scope_scene.tscn",
		"res://scenes/Day 3/day3_finale.tscn",
	]:
		var packed := load(scene_path) as PackedScene
		_check(packed != null, "%s loads" % scene_path.get_file())
		if packed != null:
			var instance := packed.instantiate()
			_check(instance != null, "%s instantiates" % scene_path.get_file())
			instance.free()
	var final_packed := load("res://scenes/Day 3/day3_finale.tscn") as PackedScene
	var finale := final_packed.instantiate() as Day3Finale
	finale.play_on_ready = false
	root.add_child(finale)
	await process_frame
	_check(finale.get_node("Audio/RouteMusic").bus == &"Ambience", "route music is routed through Ambience")
	_check(finale.get_node("Audio/Gunshot").bus == &"SFX", "gunshot is routed through SFX")
	_check(finale.get_node("Audio/Radio").bus == &"UI", "earpiece filtering is routed through UI")
	_check(Day3Finale.CG.has("dead_mc") and Day3Finale.CG.has("leader") and Day3Finale.CG.has("television"), "supplied finale CGs have named slots")
	_check(Day3Finale.CG.has("assassination") and Day3Finale.CG.has("arrests") and Day3Finale.CG.has("passports") and Day3Finale.CG.has("helicopter") and Day3Finale.CG.has("solidarity"), "generated Day 3 placeholder scenes have named CG slots")
	_check(finale.get_node_or_null("TVBroadcast") is Day3TVBroadcast, "foreign-apartment report is composited inside a TV")
	_check("Permission granted by safeinyrskin" in Day3Finale.CREDITS, "permission credit is present")
	finale.queue_free()
	await process_frame
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	var pistol_frames := player.get_node("Visual/Sprite").sprite_frames as SpriteFrames
	_check(pistol_frames.has_animation(&"pistol_draw") and pistol_frames.get_frame_count(&"pistol_draw") == 8, "Day 3 pistol draw has eight stepped animation frames")
	_check(pistol_frames.has_animation(&"pistol_aim"), "pistol animation holds its final aiming pose")
	player.free()
	_check(Day3Rooftop.SCOPE_SCENE == "res://scenes/Day 3/day3_scope_scene.tscn", "SHOOT route proceeds through the Peace Leader scope scene")
	var rooftop := (load("res://scenes/Day 3/day3_rooftop.tscn") as PackedScene).instantiate() as Day3Rooftop
	var rooftop_dialogue := rooftop.get_node("CinematicDialogue") as CinematicDialogue
	_check(rooftop_dialogue.standard_width >= 500.0 and rooftop_dialogue.speaker_offset.y >= -240.0, "rooftop dialogue is readable and positioned close above the MC")
	rooftop.free()
	var scope := (load("res://scenes/Day 3/day3_scope_scene.tscn") as PackedScene).instantiate() as Day3ScopeScene
	var scope_dialogue := scope.get_node("CinematicDialogue") as CinematicDialogue
	_check(scope_dialogue.standard_width >= 800.0 and scope_dialogue.standard_characters_per_line >= 68.0, "scope cutscene captions use a readable wide layout")
	scope.free()
	var day2 := load("res://scenes/narrative/day2_placeholder.tscn") as PackedScene
	var card := day2.instantiate()
	_check(card.get_node_or_null("ContinueToDay3") != null, "temporary Day 2 card exposes CONTINUE TO DAY 3")
	card.free()


func _check_licensed_music() -> void:
	var death_path := "res://assets/audio/day3/music/credits-song-for-my-death.mp3"
	var boss_path := "res://assets/audio/day3/music/credits-song-final-boss.mp3"
	_check(FileAccess.get_sha256(death_path).to_upper() == "15FC43CBD372839C1CA3AE65DB73F6DDA8F4784DF7DDC7E1B63697BF51C82CEE", "death-route MP3 remains byte-for-byte original")
	_check(FileAccess.get_sha256(boss_path).to_upper() == "1A90CA4E13249D2FAE912EA56EEC087344E098F7085495924B46BEB32D08BDEA", "shoot-route MP3 remains byte-for-byte original")
	_check(FileAccess.file_exists("res://docs/licenses/day3-ending-music-permission.png"), "permission screenshot is archived")
	_check(FileAccess.file_exists("res://docs/licenses/day3-ending-music-permission.md"), "permission and attribution note is archived")


func _check_both_timelines_complete() -> void:
	for ending_route in [&"not_shoot", &"shoot"]:
		var packed := load("res://scenes/Day 3/day3_finale.tscn") as PackedScene
		var finale := packed.instantiate() as Day3Finale
		finale.play_on_ready = false
		finale.instant_mode = true
		finale.timing_scale = 0.001
		finale.auto_return_to_menu = false
		root.add_child(finale)
		await process_frame
		finale.route = ending_route
		var observed := [false]
		finale.ending_completed.connect(func(_route: StringName): observed[0] = true)
		finale.play_finale()
		var frames := 0
		while not finale._ending_done and frames < 180:
			await process_frame
			frames += 1
		_check(finale._ending_done, "%s timeline reaches scrolling credits and completion" % ending_route)
		_check(observed[0], "%s emits ending_completed" % ending_route)
		finale.queue_free()
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
