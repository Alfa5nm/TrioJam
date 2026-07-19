extends SceneTree

var failures := 0
var observed_lines: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("DAY3_BRIEFING_TEST_START")
	var session := root.get_node("GameSession")
	var old_profile: String = session.profile_path
	session.profile_path = "user://day3_briefing_smoke_test.cfg"
	var packed := load("res://scenes/Day 3/day3_briefing_room.tscn") as PackedScene
	var room := packed.instantiate() as Day3BriefingRoom
	room.timing_scale = 0.01
	var dialogue := room.get_node("CinematicDialogue") as CinematicDialogue
	dialogue.instant_mode = true
	dialogue.timing_scale = 0.01
	dialogue.line_started.connect(func(text: String): observed_lines.append(text))
	root.add_child(room)
	var frames := 0
	while not room._second_conversation_ready and frames < 300:
		await process_frame
		frames += 1
	_check(room._second_conversation_ready, "opening briefing reaches the first Normal mode section")
	_check(room.player.controls_enabled, "side-scrolling control returns after the briefcase panic beat")
	_check(room.cg_image.texture == load("res://assets/art/Day3/mc-stressing.png"), "supplied stressed-MC CG closes the first exchange")
	room._play_second_exchange()
	frames = 0
	while not room._exit_armed and frames < 300:
		await process_frame
		frames += 1
	_check(room._exit_armed, "second exchange arms the required room exit")
	_check(room.player.controls_enabled, "Normal mode returns before leaving the room")
	_check(observed_lines.has("We have become more efficient, yet the leader is still alive."), "briefing preserves the Suit opening line")
	_check(observed_lines.has(". . .No fucking way. You’re telling me to kill?!"), "briefing preserves the authored panic line")
	_check(observed_lines.has("You don’t have time. Go now, or we will decide for you."), "briefing preserves the final ultimatum")
	_check(room.get_node("Suit").scale.x < 0.0, "representative placeholder faces the player")
	_check(absf(room.get_node("Suit").scale.x) >= 0.89, "representative placeholder is scaled to the room proportions")
	_check(room.player.presentation_scale >= 1.4, "MC is scaled to the room proportions")
	_check(dialogue.bark_width >= 540.0 and dialogue.bark_characters_per_line >= 44.0, "Day 3 uses wider readable world bubbles")
	_check(room.get_node("Audio/HVAC").bus == &"Ambience", "briefing HVAC is routed through Ambience")
	_check(room.get_node("Audio/Fluorescent").bus == &"Electrical", "fluorescent hum is routed through Electrical")
	room.queue_free()
	await process_frame
	session.profile_path = old_profile
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://day3_briefing_smoke_test.cfg"))
	if failures == 0:
		print("DAY3_BRIEFING_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
