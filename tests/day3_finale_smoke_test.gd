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
	await _check_credits_checkpoint_music_restore()
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
				for day2_route in [&"truthful", &"propaganda"]:
					session.day0_rooftop_route = day0_route
					session.day1_checkpoint_route = report_one
					session.day1_seedless_route = report_two
					session.day2_bombing_route = day2_route
					var truth_count := [report_one, report_two, day2_route].count(&"truthful")
					var expected: StringName = &"not_shoot" if truth_count >= 2 else &"shoot"
					var key := "%s/%s/%s/%s" % [day0_route, report_one, report_two, day2_route]
					_check(session.resolve_day3_route() == expected, "%s ignores Day 0 and resolves the later three-report majority to %s" % [key, expected])
	session.day0_rooftop_route = &""
	session.day1_checkpoint_route = &"truthful"
	session.day1_seedless_route = &"truthful"
	session.day2_bombing_route = &"propaganda"
	_check(session.has_complete_day3_report_history(), "the later three reports form complete history without Day 0")
	_check(session.resolve_day3_route() == &"not_shoot", "Day 0 can be absent without changing the later reports' NOT SHOOT majority")
	_check(session.CHECKPOINT_SCENES.has("day3_credits"), "credits have a resumable Day 3 checkpoint")


func _check_debug_fallback() -> void:
	session.day0_rooftop_route = &""
	session.day1_checkpoint_route = &""
	session.day1_seedless_route = &""
	session.day2_bombing_route = &""
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
	_check(finale.gunshot.stream.resource_path.ends_with("pistol-shot.mp3"), "MC shooting and being shot use the supplied pistol cue")
	_check(finale.body_fall.stream.resource_path.ends_with("body-fall.mp3"), "NOT SHOOT collapse uses the supplied body-fall cue")
	_check(finale.get_node("Audio/Radio").bus == &"UI", "earpiece filtering is routed through UI")
	_check(Day3Finale.CG.has("mc_shot_impact") and Day3Finale.CG.has("dead_mc") and Day3Finale.CG.has("leader") and Day3Finale.CG.has("television"), "supplied impact and finale CGs have named slots")
	_check(String(Day3Finale.CG["day0_shot"]).ends_with("choice-consequence.png") and FileAccess.file_exists(Day3Finale.CG["day0_shot"]), "choice-consequence narration uses the supplied red and blue CG")
	_check(FileAccess.file_exists(Day3Finale.CG["mc_shot_impact"]), "NOT SHOOT impact CG is stored in the project")
	_check(Day3Finale.CG.has("news_podium") and Day3Finale.CG.has("news_unrest") and Day3Finale.CG.has("news_military"), "reporter beats use dedicated empty-podium, unrest, and military B-roll")
	_check(Day3Finale.CG.has("assassination") and Day3Finale.CG.has("arrests") and Day3Finale.CG.has("passports") and Day3Finale.CG.has("helicopter") and Day3Finale.CG.has("solidarity"), "generated Day 3 placeholder scenes have named CG slots")
	_check(finale.get_node_or_null("TVBroadcast") is Day3TVBroadcast, "foreign-apartment report is composited inside a TV")
	_check(finale.get_node_or_null("TVBroadcast/StoryImage") is TextureRect, "television broadcast supports dialogue-specific B-roll")
	_check(finale.get_node_or_null("CenterCard/Title") is Label, "shoot-route title cards are centered independently of bottom captions")
	_check(finale.get_node_or_null("Credits/TitleBackdrop") is TextureRect, "ending credits reuse the supplied title-screen artwork")
	_check(finale.get_node_or_null("Credits/CRT") is ColorRect and finale.get_node("Credits/CRT").material is ShaderMaterial, "ending credits retain the CRT presentation")
	_check(finale.credits_text.material is ShaderMaterial, "scrolling credits have an isolated alpha-mask material")
	var credits_shader := (finale.credits_text.material as ShaderMaterial).shader
	_check(credits_shader != null and "SCREEN_UV.y" in credits_shader.code and "smoothstep" in credits_shader.code, "credits mask fades text in screen space")
	_check("= 0.30" in credits_shader.code and "= 0.46" in credits_shader.code, "credits fade band sits immediately below the NOW, TODAY'S NEWS title")
	_check(finale.credits_hint.material == null and finale.get_node("Credits/CRT").material != finale.credits_text.material, "credits mask does not affect the skip hint or CRT overlay")
	var expected_credits: Array[String] = [
		"MADE FOR IUT GAME JAM",
		"Under the theme “Kick-off”",
		"",
		"Tasnuva: Project lead, Game Mechanics and Designer",
		"Farid: Lead Programmer, Side-Scrolling and Environmental Artist and Engineer",
		"Akib: Programmer, Logistics, Game mechanics",
		"",
		"Made in: Godot.",
		"Music credits: vivivivivi (aka safeinyrskin), GreenBearMusic and other free artists found in Pixabay",
		"",
		"Thank you for playing!",
	]
	_check(Day3Finale.CREDITS == expected_credits, "finale uses the supplied IUT Game Jam credit copy verbatim")
	finale._begin_cg_parallax()
	_check(finale._cg_parallax_active and finale.image.scale.is_equal_approx(Day3Finale.CG_PARALLAX_SCALE), "finale still CGs enable subtle overscaled mouse parallax")
	_check(Day3Finale.CG_PARALLAX_MAX_OFFSET.x <= 10.0 and Day3Finale.CG_PARALLAX_MAX_OFFSET.y <= 6.0, "finale parallax remains inside the safe crop")
	finale._end_cg_parallax()
	_check(not finale._cg_parallax_active and finale.image.scale.is_equal_approx(Vector2.ONE), "cards and credits disable CG parallax")
	finale.instant_mode = true
	await finale._line("GOVERNMENT REPRESENTATIVE — EARPIECE", "Fire", Color.RED)
	_check(finale.caption.text == "Fire", "Government earpiece header is hidden from ending dialogue")
	_check(finale.caption.get_theme_color(&"default_color").is_equal_approx(Color.RED), "Government earpiece dialogue, including Fire, renders red")
	var government_box := finale.caption_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	_check(government_box.bg_color.r > government_box.bg_color.b and government_box.border_color.r > 0.9, "Government earpiece dialogue box carries a dark red hue and red border")
	await finale._line("MC — NARRATION", "A final thought.", Color.WHITE)
	_check(finale.caption.text == "A final thought.", "MC narration header is hidden from ending dialogue")
	_check(finale.caption.get_theme_color(&"default_color").is_equal_approx(Color.WHITE), "finale caption color updates for the next speaker instead of staying red")
	var mc_box := finale.caption_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	_check(mc_box.border_color.b > mc_box.border_color.r, "MC dialogue restores the default blue box after Government lines")
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
	var day2 := load("res://scenes/Day 2/day2_peace_rally.tscn") as PackedScene
	var rally := day2.instantiate()
	_check(rally.get_node_or_null("Player") is Player, "Day 2 now starts as a playable side-scrolling rally")
	_check(rally.get_node_or_null("World/AftermathBackground") is Sprite2D, "Day 2 carries a dedicated explosion-aftermath layer")
	rally.free()


func _check_licensed_music() -> void:
	var death_path := "res://assets/audio/day3/music/credits-song-for-my-death.mp3"
	var boss_path := "res://assets/audio/day3/music/credits-song-final-boss.mp3"
	_check(FileAccess.get_sha256(death_path).to_upper() == "15FC43CBD372839C1CA3AE65DB73F6DDA8F4784DF7DDC7E1B63697BF51C82CEE", "death-route MP3 remains byte-for-byte original")
	_check(FileAccess.get_sha256(boss_path).to_upper() == "1A90CA4E13249D2FAE912EA56EEC087344E098F7085495924B46BEB32D08BDEA", "shoot-route MP3 remains byte-for-byte original")
	_check(FileAccess.file_exists("res://docs/licenses/day3-ending-music-permission.png"), "permission screenshot is archived")
	_check(FileAccess.file_exists("res://docs/licenses/day3-ending-music-permission.md"), "permission and attribution note is archived")


func _check_both_timelines_complete() -> void:
	for ending_route in [&"not_shoot", &"shoot"]:
		session.stop_day3_route_music()
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
		var observed_tv_stories: Array[String] = []
		var observed_cards: Array[String] = []
		var music_playing_at_first_line := [false]
		var music_player_at_first_line := [null]
		finale.ending_completed.connect(func(_route: StringName): observed[0] = true)
		finale.line_started.connect(func(_speaker: String, text: String):
			if observed_lines.is_empty():
				music_playing_at_first_line[0] = finale.route_music.playing
				music_player_at_first_line[0] = finale.route_music
			observed_lines.append(text)
		)
		finale.image_shown.connect(func(key: String): observed_images.append(key))
		finale.tv_story_shown.connect(func(key: String): observed_tv_stories.append(key))
		finale.center_card_shown.connect(func(text: String): observed_cards.append(text))
		finale.play_finale()
		var frames := 0
		while not finale._ending_done and frames < 180:
			await process_frame
			frames += 1
		_check(finale._ending_done, "%s timeline reaches scrolling credits and completion" % ending_route)
		_check(observed[0], "%s emits ending_completed" % ending_route)
		_check(music_playing_at_first_line[0], "%s route music is already playing when its first ending line begins" % ending_route)
		var expected_cue := &"day3_not_shoot" if ending_route == &"not_shoot" else &"day3_shoot"
		var expected_track := "credits-song-for-my-death.mp3" if ending_route == &"not_shoot" else "credits-song-final-boss.mp3"
		var music_director := root.get_node("MusicDirector")
		_check(finale.route_music == music_player_at_first_line[0], "%s credits inherit the same route-music player" % ending_route)
		_check(music_director.current_cue() == expected_cue, "%s credits retain their route-specific cue" % ending_route)
		_check(finale.route_music.stream.resource_path.ends_with(expected_track), "%s credits retain their route-specific stream" % ending_route)
		_check(finale.route_music.stream is AudioStreamMP3 and (finale.route_music.stream as AudioStreamMP3).loop, "%s route score loops through its credits" % ending_route)
		var expected_heading := "Oroboros Route" if ending_route == &"not_shoot" else "Running away from Consequences Route"
		_check(finale.credits_text.text.begins_with(expected_heading + "\n\nMADE FOR IUT GAME JAM"), "%s credits keep only the route heading before the supplied copy" % ending_route)
		_check("AND NOW, TODAY'S NEWS" not in finale.credits_text.text, "%s credits remove the old news header" % ending_route)
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
			_check(observed_images == ["tv_broadcast", "passports", "tv_broadcast", "television"], "SHOOT aftermath keeps all news footage inside the foreign-apartment television")
			_check(observed_tv_stories == ["news_podium", "arrests", "news_military", "news_unrest", "news_military"], "SHOOT television selects assassination, arrests, unrest, and military footage at the appropriate lines")
			_check(observed_cards == ["And Now, Today’s News.", "Running away from Consequences Route"], "SHOOT ending uses the two centered authored title cards")
		else:
			_check(observed_tv_stories.is_empty() and "tv_broadcast" not in observed_images, "NOT SHOOT keeps its death and solidarity montage outside the foreign apartment")
			_check("mc_shot_impact" in observed_images, "NOT SHOOT shows the supplied impact CG immediately after MC refuses")
			_check(observed_images.find("mc_shot_impact") < observed_images.find("dead_mc"), "impact CG precedes the dead-MC news image")
			_check(observed_cards == ["Oroboros Route"], "NOT SHOOT ending is named Oroboros Route")
		finale.queue_free()
		await process_frame
		session.stop_day3_route_music()


func _check_credits_checkpoint_music_restore() -> void:
	for ending_route in [&"not_shoot", &"shoot"]:
		session.stop_day3_route_music()
		session.day3_resolution = ending_route
		session.checkpoint = "day3_credits"
		var finale := (load("res://scenes/Day 3/day3_finale.tscn") as PackedScene).instantiate() as Day3Finale
		finale.instant_mode = true
		finale.auto_return_to_menu = false
		root.add_child(finale)
		var frames := 0
		while not finale._ending_done and frames < 30:
			await process_frame
			frames += 1
		var expected_cue := &"day3_not_shoot" if ending_route == &"not_shoot" else &"day3_shoot"
		var expected_track := "credits-song-for-my-death.mp3" if ending_route == &"not_shoot" else "credits-song-final-boss.mp3"
		var music_director := root.get_node("MusicDirector")
		_check(finale._ending_done, "%s credits checkpoint resumes directly into credits" % ending_route)
		_check(music_director.current_cue() == expected_cue, "%s credits checkpoint restores the correct route cue" % ending_route)
		_check(finale.route_music != null and finale.route_music.playing and finale.route_music.stream.resource_path.ends_with(expected_track), "%s credits checkpoint restores the correct route song" % ending_route)
		finale.queue_free()
		await process_frame
		session.stop_day3_route_music()
	session.checkpoint = ""


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
