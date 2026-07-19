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
	session.stop_day3_route_music()
	session.profile_path = original_profile_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://day3_finale_smoke_test.cfg"))
	if failures == 0:
		print("DAY3_FINALE_TEST_PASS")
	quit(failures)


func _check_route_matrix() -> void:
	for day0_route in [&"truthful", &"propaganda"]:
		for report_one in [&"truthful", &"propaganda"]:
			for report_two in [&"truthful", &"propaganda"]:
				session.day0_rooftop_route = day0_route
				session.day1_checkpoint_route = report_one
				session.day1_seedless_route = report_two
				var truth_count := [day0_route, report_one, report_two].count(&"truthful")
				var expected: StringName = &"not_shoot" if truth_count >= 2 else &"shoot"
				var key := "%s/%s/%s" % [day0_route, report_one, report_two]
				_check(session.resolve_day3_route() == expected, "%s resolves by two-of-three majority to %s" % [key, expected])
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
	_check(Day3Finale.CG.has("news_podium") and Day3Finale.CG.has("news_unrest") and Day3Finale.CG.has("news_military"), "reporter beats use dedicated empty-podium, unrest, and military B-roll")
	_check(Day3Finale.CG.has("assassination") and Day3Finale.CG.has("arrests") and Day3Finale.CG.has("passports") and Day3Finale.CG.has("helicopter") and Day3Finale.CG.has("solidarity"), "generated Day 3 placeholder scenes have named CG slots")
	_check(finale.get_node_or_null("TVBroadcast") is Day3TVBroadcast, "foreign-apartment report is composited inside a TV")
	_check(finale.get_node_or_null("TVBroadcast/StoryImage") is TextureRect, "television broadcast supports dialogue-specific B-roll")
	_check(finale.get_node_or_null("CenterCard/Title") is Label, "shoot-route title cards are centered independently of bottom captions")
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
	_check(scope.get_node_or_null("PreScope/GunCG") is TextureRect, "SHOOT monologue uses the supplied pistol CG before the scope")
	_check(scope.get_node_or_null("ScopeUI/RedFlash") is ColorRect, "successful scope shot has a dedicated red flash")
	_check(scope.get_node_or_null("ScopeUI/ShotParticles") is CPUParticles2D and (scope.get_node("ScopeUI/ShotParticles") as CPUParticles2D).one_shot, "successful scope shot uses a bounded one-shot particle burst")
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
		var observed_lines: Array[String] = []
		var observed_images: Array[String] = []
		var observed_cards: Array[String] = []
		finale.ending_completed.connect(func(_route: StringName): observed[0] = true)
		finale.line_started.connect(func(_speaker: String, text: String): observed_lines.append(text))
		finale.image_shown.connect(func(key: String): observed_images.append(key))
		finale.center_card_shown.connect(func(text: String): observed_cards.append(text))
		finale.play_finale()
		var frames := 0
		while not finale._ending_done and frames < 180:
			await process_frame
			frames += 1
		_check(finale._ending_done, "%s timeline reaches scrolling credits and completion" % ending_route)
		_check(observed[0], "%s emits ending_completed" % ending_route)
		if ending_route == &"shoot":
			var expected_lines: Array[String] = [
				"The Opposition Peace Leader was assassinated today by a radical member of their own movement.",
				"Authorities believe violent divisions within the Opposition led to the attack.",
				"The military has assumed emergency control to restore order.",
				"Citizens are instructed to remain indoors.",
				"Like cowards, we fled to another country.",
				"All it took for the government was a helicopter and false passports. It’s honestly laughable how easy it all was.",
				"I turn to the television.",
				"Necessary force was used against armed rioters.",
				"Enemy sympathizers have attacked government supply routes.",
				"Order will soon be restored.",
				"They kept their promise, and my family survived.",
				"The Opposition fractured, and the soldiers went to the streets. Hunger became riots, and riots became war.",
				"Every report used words I had given them.",
				"I saved the people inside this apartment, and I destroyed the only person who might have saved everyone outside it.",
			]
			_check(observed_lines == expected_lines, "SHOOT aftermath preserves every submitted line in exact order")
			_check(observed_images == ["news_podium", "news_unrest", "news_military", "passports", "tv_broadcast", "television"], "SHOOT aftermath uses contextual news B-roll, then passports, TV, and couch")
			_check(observed_cards == ["And Now, Today’s News.", "Running away from Consequences Route"], "SHOOT ending uses the two centered authored title cards")
		finale.queue_free()
		await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
