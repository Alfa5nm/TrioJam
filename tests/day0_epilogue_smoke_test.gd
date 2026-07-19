extends SceneTree

var failures := 0


func _init() -> void:
	print("DAY0_EPILOGUE_TEST_START")
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://scenes/narrative/day0_epilogue.tscn") as PackedScene
	_check(packed_scene != null, "Day 0 epilogue scene loads")
	if packed_scene == null:
		quit(1)
		return
	var scene := packed_scene.instantiate() as Day0Epilogue
	scene.instant_mode = true
	scene.timing_scale = 0.01
	scene.auto_advance_to_day1 = false
	root.add_child(scene)
	await process_frame

	_check(not scene.bedroom.visible, "civilian accusations begin on a pure black screen")
	var dialogue_style := scene.dialogue_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(dialogue_style.bg_color.is_equal_approx(Color(0.0431373, 0.113725, 0.301961, 0.96)), "epilogue dialogue uses the navy backdrop")
	_check(dialogue_style.border_color.is_equal_approx(Color(0.133333, 0.839216, 1.0, 0.96)), "epilogue dialogue uses the neon-blue outline")
	_check(scene.dialogue_label.get_theme_color("font_color") == Color.WHITE, "epilogue dialogue text remains white")
	_check(scene.dialogue_label.get_theme_font("font").resource_path.ends_with("Newsreader.ttf"), "epilogue dialogue uses the newsletter font")
	_check(scene.has_node("DialoguePanel/Margin/Layout/SpeakerLabel") and scene.speaker_label.text == "Civilian 1", "first civilian dialogue displays its requested header")
	_check(scene.dialogue_label.text == "They murdered him!", "first accusation is exact")
	scene._request_advance()
	_check(scene._civilian_index == 0 and scene._hold_active, "first civilian cry cannot advance during its mandatory hold")
	await create_timer(0.02).timeout
	scene._request_advance()
	_check(scene.dialogue_label.text == "You believe everything they show you!", "second civilian cry follows the first hold")
	_check(scene.speaker_label.text == "Civilian 2", "second civilian header advances with its dialogue")
	await create_timer(0.02).timeout
	scene._request_advance()
	_check(scene.dialogue_label.text == "The Opposition started this!" and scene.speaker_label.text == "Civilian 3", "third civilian dialogue and header appear together")
	scene._request_advance()
	_check(not scene.bedroom.visible and scene._hold_active, "final civilian cry holds before the bedroom reveal")
	await create_timer(0.03).timeout
	scene._request_advance()
	await process_frame
	_check(scene.bedroom.visible and scene._bedroom_index == 0, "bedroom cutscene begins only after the black-screen dialogue")
	_check(not scene.speaker_label.visible, "speaker header clears for internal bedroom narration")
	_check(scene.dialogue_label.text.begins_with("I watched as the civilians"), "bedroom narration opens with the requested line")
	_check(scene.curtains.sprite_frames.get_frame_count(&"close") == 2, "curtain close uses the two supplied illustrations")
	_check(scene.curtains.sprite_frames.get_frame_texture(&"close", 0) == Day0Epilogue.CURTAIN_PULL, "curtain pull is the first frame")
	_check(scene.curtains.sprite_frames.get_frame_texture(&"close", 1) == Day0Epilogue.CURTAIN_ENDING, "curtain ending is the second frame")
	_check(not scene.curtains.visible, "curtain illustrations remain hidden until the closing beat")
	_check(scene.ambience.stream != null and scene.ambience.bus == &"Ambience", "Day Zero ending ambience is assigned to the Ambience bus")
	_check(scene.music.stream != null and scene.music.bus == &"Ambience", "Day Zero ending music is assigned to the Ambience bus")
	_check(scene.ambience.autoplay and scene.music.autoplay, "Day Zero ambience and music begin automatically")
	_check(scene.ambience.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED and scene.music.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED, "Day Zero ambience and music loop cleanly")
	_check(scene.curtain_impact.stream != null and scene.curtain_impact.bus == &"SFX", "curtain landing impact is assigned to SFX")
	var session := root.get_node("GameSession")
	_check(session.has_method(&"begin_day1_scene1") and session.CHECKPOINT_SCENES.get("day1_scene1") == Day0Epilogue.DAY1_SCENE, "Day Zero completion has a persistent Day 1 Scene 1 checkpoint")

	for _line in 4:
		scene._request_advance()
	_check(scene._bedroom_index == 4, "gunshot consequence line occurs at the intended narrative beat")
	_check(scene.gun_flash.modulate.a > 0.0 or scene.protest_glow.modulate.a > 0.12, "gunshot line activates unrest reflections")
	for _line in 3:
		scene._request_advance()
	_check(scene.dialogue_label.text == "...", "silence precedes closing the curtains")
	scene._request_advance()
	_check(scene._closing and scene.curtains.visible and scene.curtains.is_playing(), "advancing from silence starts on the curtain-pull illustration")
	await create_timer(0.12).timeout
	_check(scene._finished and scene.dialogue_label.text == "I have to work tomorrow...", "final line appears after the curtains fully close")
	_check(scene.curtains.frame == 1 and scene.curtains.sprite_frames.get_frame_texture(&"close", scene.curtains.frame) == Day0Epilogue.CURTAIN_ENDING, "curtain-ending illustration remains on screen for the final line")
	_check(not scene._transition_started, "tests can disable the automatic Day 1 handoff")

	scene.queue_free()
	await process_frame
	if failures == 0:
		print("DAY0_EPILOGUE_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
