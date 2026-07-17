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
	root.add_child(scene)
	await process_frame

	_check(not scene.bedroom.visible, "civilian accusations begin on a pure black screen")
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
	_check(scene.curtains.sprite_frames.get_frame_count(&"close") == 4, "curtain close is a generated four-frame animation")

	for _line in 4:
		scene._request_advance()
	_check(scene._bedroom_index == 4, "gunshot consequence line occurs at the intended narrative beat")
	_check(scene.gun_flash.modulate.a > 0.0 or scene.protest_glow.modulate.a > 0.12, "gunshot line activates unrest reflections")
	for _line in 3:
		scene._request_advance()
	_check(scene.dialogue_label.text == "...", "silence precedes closing the curtains")
	scene._request_advance()
	_check(scene._closing and scene.curtains.is_playing(), "advancing from silence closes the curtains")
	await create_timer(1.6).timeout
	_check(scene._finished and scene.dialogue_label.text == "I have to work tomorrow...", "final line appears after the curtains fully close")

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
