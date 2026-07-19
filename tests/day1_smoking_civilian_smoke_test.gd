extends SceneTree

const SCENE_PATH := "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn"

var failures := 0


func _initialize() -> void:
	print("DAY1_SMOKING_CIVILIAN_TEST_START")
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "Day 1 scene loads with the smoking civilian encounter")
	if packed == null:
		quit(1)
		return

	var level := packed.instantiate()
	var dialogue := level.get_node("CinematicDialogue") as CinematicDialogue
	dialogue.timing_scale = 0.01
	root.add_child(level)
	for _frame in 5:
		await physics_frame

	var encounter := level.get_node_or_null("SmokingCivilianEncounter") as AmbientBarkTrigger
	var player := level.get_node_or_null("Player") as Player
	_check(encounter != null, "ambient bark trigger is instanced at the marked tree")
	_check(encounter != null and encounter.position.x > 1500.0 and encounter.position.x < 2200.0, "encounter remains in the authored tree section")
	_check(encounter != null and encounter.speaker_name == "Smoking civilian", "speaker label is exact")
	_check(encounter != null and encounter.dialogue_text == "This country is doomed from the start", "ambient dialogue is exact")
	_check(encounter != null and encounter.blip_stream != null, "coarse civilian blip is assigned")
	_check(encounter != null and encounter.z_index >= 4 and encounter.placeholder_visual.get_global_transform_with_canvas().get_origin().is_finite(), "smoking civilian renders in the NPC layer instead of behind the street")
	_check(dialogue.blip.bus == &"UI", "ambient dialogue blip uses the UI bus")
	_check(player != null and player.controls_enabled, "player starts with movement enabled")

	var desired_anchor_screen := Vector2(640.0, 420.0)
	encounter.dialogue_anchor.global_position = dialogue.get_viewport().get_canvas_transform().affine_inverse() * (desired_anchor_screen - dialogue.bark_speaker_offset)
	player.global_position = encounter.global_position + Vector2(0.0, -30.0)
	player.velocity = Vector2.ZERO
	for _frame in 3:
		await physics_frame
	_check(encounter.has_triggered, "walking past the civilian triggers the bark")
	_check(player.controls_enabled, "ambient bark does not interrupt player movement")
	_check(not dialogue.speaker_label.visible and dialogue.speaker_label.text.is_empty(), "ambient dialogue omits the speaker name")
	_check(dialogue.line.text == "This country is doomed from the start", "bubble displays the requested sentence")
	_check(dialogue.line.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and dialogue.bubble.size.x == 460.0 and dialogue.bubble.size.y >= 90.0, "ambient bubble stays compact and wraps the sentence")
	var bubble_bottom_center := dialogue.bubble.position + Vector2(dialogue.bubble.size.x * 0.5, dialogue.bubble.size.y)
	_check(bubble_bottom_center.distance_to(dialogue._parallax_anchor_origin) < 4.0, "dialogue initially appears directly above the civilian")
	var bubble_start := dialogue.bubble.position
	var full_anchor_start := dialogue.get_viewport().get_canvas_transform() * encounter.dialogue_anchor.global_position
	encounter.dialogue_anchor.position.x += 120.0
	dialogue._place_bubble()
	var full_anchor_end := dialogue.get_viewport().get_canvas_transform() * encounter.dialogue_anchor.global_position
	var full_motion := full_anchor_end.x - full_anchor_start.x
	var bubble_motion := dialogue.bubble.position.x - bubble_start.x
	_check(absf(bubble_motion) > absf(full_motion) * 0.85 and absf(bubble_motion) < absf(full_motion), "ambient bubble follows its speaker with a subtle parallax lag")
	_check(not dialogue.continue_cue.visible, "ambient bark has no continue prompt")
	_check(dialogue.blip.stream == encounter.blip_stream, "ambient bark selects the coarse blip override")
	var blip_wait_frames := 0
	while dialogue._last_blip_time <= 0.0 and blip_wait_frames < 30:
		await process_frame
		blip_wait_frames += 1
	_check(dialogue._last_blip_time > 0.0, "typewriter playback emits the coarse character blip")

	encounter.trigger_bark()
	await process_frame
	_check(encounter.has_triggered, "encounter remains consumed after a repeated trigger attempt")
	_check(player.controls_enabled, "repeated trigger attempts never lock controls")
	for _frame in 90:
		await process_frame
	_check(not dialogue.dialogue.visible and not dialogue.is_presenting, "ambient bark dismisses automatically")
	_check(dialogue.bubble.size == Vector2(430.0, 86.0) and not dialogue.speaker_label.visible, "shared dialogue returns to its standard layout")

	level.queue_free()
	for _frame in 3:
		await process_frame
	var reloaded_level := packed.instantiate()
	root.add_child(reloaded_level)
	await process_frame
	var reloaded_encounter := reloaded_level.get_node("SmokingCivilianEncounter") as AmbientBarkTrigger
	_check(not reloaded_encounter.has_triggered, "reloading Day 1 resets the encounter")
	reloaded_level.queue_free()
	await process_frame
	if failures == 0:
		print("DAY1_SMOKING_CIVILIAN_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
