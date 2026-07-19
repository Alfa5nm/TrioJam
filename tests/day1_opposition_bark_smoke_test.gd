extends SceneTree

const SCENE_PATH := "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn"
const PREVIEW_PATH := "res://tests/artifacts/day1_opposition_peace_bark_preview.png"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "Day 1 loads with the opposition peace bark")
	if packed == null:
		quit(1)
		return
	var level := packed.instantiate()
	root.add_child(level)
	for _frame in 6:
		await process_frame

	var encounter := level.get_node_or_null("OppositionPeaceEncounter") as AmbientBarkTrigger
	var dialogue := level.get_node("CinematicDialogue") as CinematicDialogue
	var player := level.get_node("Player") as Player
	var camera := level.get_node("HorizontalCamera") as Day1HorizontalCamera
	_check(encounter != null, "opposition NPC uses the reusable ambient-bark encounter")
	if encounter == null:
		level.queue_free()
		quit(1)
		return

	_check(encounter.position.distance_to(Vector2(8010, 607)) < 1.0, "opposition NPC occupies the marked restricted-area pavement")
	_check(encounter.speaker_name == "Opposition", "speaker role is Opposition")
	_check(encounter.dialogue_text == "All we want is peace…!", "peace dialogue matches exactly")
	_check(encounter.placeholder_visual.texture.resource_path.ends_with("r4c1-anti-seedless-protester-a.png"), "NPC uses the normal-looking male anti-Seedless character")
	_check(encounter.placeholder_visual.flip_h and encounter.placeholder_visual.scale.distance_to(Vector2(0.72, 0.72)) < 0.001, "male NPC faces the approaching player at the correct scale")
	_check(encounter.dialogue_anchor.global_position.y < encounter.placeholder_visual.global_position.y, "dialogue anchor sits above the NPC")

	var shown_text := [""]
	var bark_count := [0]
	dialogue.line_started.connect(func(text: String) -> void: shown_text[0] = text)
	encounter.bark_started.connect(func() -> void: bark_count[0] += 1)
	dialogue.instant_mode = true
	dialogue.timing_scale = 0.01
	var controls_before := player.controls_enabled
	encounter.trigger_bark()
	await encounter.bark_finished
	_check(shown_text[0] == "All we want is peace…!", "walking past shows the requested line")
	_check(player.controls_enabled == controls_before, "ambient opposition bark never locks player movement")
	_check(not dialogue.speaker_label.visible and dialogue.speaker_label.text.is_empty(), "ambient bark hides the speaker name")
	_check(encounter.has_triggered and not encounter.monitoring, "opposition bark is consumed after one play")
	encounter.trigger_bark()
	await process_frame
	_check(bark_count[0] == 1, "opposition bark cannot replay during the same visit")
	dialogue._apply_speaker_style("Opposition")
	var opposition_color := dialogue.line.get_theme_color(&"font_color")
	_check(opposition_color.r > 0.9 and opposition_color.g > 0.6 and opposition_color.b < 0.5, "Opposition bubble uses the established amber faction styling")

	if DisplayServer.get_name() != "headless":
		camera.position_smoothing_enabled = false
		camera.target = encounter
		camera.framing_offset = Vector2(0, -213)
		for _frame in 5:
			await process_frame
		_preview_bubble(dialogue, encounter)
		await process_frame
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
		var image := root.get_viewport().get_texture().get_image()
		_check(image.save_png(ProjectSettings.globalize_path(PREVIEW_PATH)) == OK, "opposition bark preview saves")

	level.queue_free()
	for _frame in 3:
		await process_frame
	quit(failures)


func _preview_bubble(dialogue: CinematicDialogue, encounter: AmbientBarkTrigger) -> void:
	dialogue._configure_ambient_bark("Opposition", "All we want is peace…!", encounter.blip_stream)
	dialogue._speaker = encounter.dialogue_anchor
	dialogue._uses_screen_anchor = false
	dialogue._uses_parallax_anchor = true
	dialogue._parallax_anchor_initialized = false
	dialogue.is_presenting = true
	dialogue.dialogue.visible = true
	dialogue.bubble.modulate.a = 1.0
	dialogue.bubble.scale = Vector2.ONE
	dialogue.line.text = "All we want is peace…!"
	dialogue.line.visible_characters = -1
	dialogue._place_bubble()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
