extends SceneTree

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("DAY3_SCOPE_TEST_START")
	var session := root.get_node("GameSession")
	var old_profile: String = session.profile_path
	session.profile_path = "user://day3_scope_smoke_test.cfg"
	var packed := load("res://scenes/Day 3/day3_scope_scene.tscn") as PackedScene
	_check(packed != null, "Day 3 scope scene loads")
	var scope := packed.instantiate() as Day3ScopeScene
	scope.auto_advance_to_finale = false
	scope.play_intro_on_ready = false
	scope.cinematic_timing_scale = 0.01
	root.add_child(scope)
	await process_frame
	scope.dialogue.instant_mode = true
	scope.dialogue.timing_scale = 0.01
	await scope.dialogue.show_government_command_at("Fire.", Vector2(640, 650), 0.01)
	var command_box := scope.dialogue.panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	_check(scope.dialogue.line.get_theme_color(&"font_color").r > 0.9 and command_box.bg_color.r > command_box.bg_color.b and command_box.border_color.r > 0.9, "Fire command uses red text with a dark red dialogue box")
	await scope.dialogue.show_line_at("MC", Vector2(640, 650), 0.01)
	var restored_box := scope.dialogue.panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	_check(restored_box.border_color.b > restored_box.border_color.r, "dialogue box returns to blue after the Government command")
	_check(scope.get_node("TargetImage").texture == load("res://assets/art/Day3/peace-leader-podium.png"), "scope targets the supplied Peace Leader podium scene")
	_check(scope.pistol_shot.stream.resource_path.ends_with("pistol-shot.mp3"), "leader assassination uses the supplied pistol shot")
	_check(not scope.attempt_shot_at(Vector2(100, 100)), "off-target pistol shot is rejected")
	var resolution_finished := [false]
	scope.resolution_sequence_finished.connect(func(): resolution_finished[0] = true)
	_check(scope.attempt_shot_at(Vector2(640, 340)), "Peace Leader target accepts the determined shot")
	var frames := 0
	while not resolution_finished[0] and frames < 120:
		await process_frame
		frames += 1
	_check(scope.resolved, "scope resolves after the target is confirmed")
	_check(resolution_finished[0], "Peace Leader line, pistol shot, red flash, and blackout finish after target confirmation")
	var route_player: AudioStreamPlayer = session.get_day3_route_music_player()
	_check(route_player.playing, "final-boss credits track starts on the assassination gunshot")
	_check(route_player.stream is AudioStreamMP3 and (route_player.stream as AudioStreamMP3).loop, "SHOOT route track is ready to continue looping through credits")
	session.stop_day3_route_music()
	scope.queue_free()
	await process_frame
	session.profile_path = old_profile
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://day3_scope_smoke_test.cfg"))
	if failures == 0:
		print("DAY3_SCOPE_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
